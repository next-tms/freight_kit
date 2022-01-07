# frozen_string_literal: true

module Interstellar
  class CLNI < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Clear Lane Freight Systems'
    @@scac = 'CLNI'

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(10_000, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(8, :feet)
    end

    def overlength_fees_require_tariff?
      false
    end

    # Documents

    # Rates
    def find_rates(origin, destination, packages, options = {})
      options = @options.merge(options)

      origin = Location.from(origin)
      destination = Location.from(destination)
      packages = Array(packages)

      validate_packages(packages)
      raise UnserviceableError, 'Must be fewer than 10 items altogether' if packages.sum(&:quantity) > 10

      request = build_rate_request(origin, destination, packages, options)
      parse_rate_response(origin, destination, commit_soap(:rates, request))
    end

    def find_rates_implemented?
      true
    end

    # Tracking

    protected

    def commit_soap(action, request)
      Savon.client(
        wsdl: request_url(action),
        convert_request_keys_to: :none,
        env_namespace: :soap,
        element_form_default: :qualified
      ).call(
        @conf.dig(:api, :actions, action),
        message: request_blueprint.deep_merge(request)
      )&.body&.to_hash&.with_indifferent_access
    end

    def request_blueprint
      {
        'request': {
          'Application': 'ThirdParty',
          'AccountNumber': @options[:account],
          'UserID': @options[:username],
          'Password': @options[:password],
          'TestMode': @options[:debug].blank? ? 'N' : 'Y'
        }
      }
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
    end

    # Documents

    # Rates
    def build_rate_request(origin, destination, packages, options = {})
      options = @options.merge(options)

      accessorial_input = []
      unless options[:accessorials].blank?
        serviceable_accessorials?(options[:accessorials])
        options[:accessorials].each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorial_input << { 'AccessorialInput': { 'AccessorialCode': @conf.dig(:accessorials, :mappable)[a] } }
          end
        end
      end

      accessorial_input.uniq!

      commodity_input = []
      dimensions = []
      packages.each do |package|
        commodity_input << {
          'CommodityInput': {
            'CommodityClass': package.freight_class,
            'CommodityHazmat': package.hazmat? ? 'Y' : 'N',
            'CommodityHeight': package.height(:in).ceil,
            'CommodityLength': package.length(:in).ceil,
            'CommodityPieces': package.quantity,
            'CommodityPieceType': package.packaging.pallet? ? 'pallet' : 'box',
            'CommodityWeight': package.pounds(:total).ceil,
            'CommodityWeightPerPiece': package.pounds(:each).ceil,
            'CommodityWidth': package.width(:in).ceil
          }
        }
      end

      pickup_from = DateTime.current.beginning_of_day + 14.hours
      pickup_from += 1.day if DateTime.current > pickup_from
      pickup_to = pickup_from + 3.hours

      request = {
        'RatingParam': {
          'AccessorialInput': accessorial_input,
          'CommodityInput': commodity_input,
          'RatingInput': {
            'DeclaredValue': 0,
            'DestinationCity': destination.to_hash[:city],
            'DestinationCountry': destination.country.code(:alpha2).to_s,
            'DestinationState': destination.to_hash[:province],
            'DestinationZip': destination.to_hash[:postal_code],
            'LiabilityType': '',
            'OriginCity': origin.to_hash[:city],
            'OriginCountry': origin.country.code(:alpha2).to_s,
            'OriginState': origin.to_hash[:province],
            'OriginZip': origin.to_hash[:postal_code],
            'Palletized': packages.map(&:packaging).map(&:pallet?).any?(false) ? 'N' : 'Y',
            'PickupDate': pickup_from.to_date.strftime('%Y-%m-%d'),
            'PickupLocationCloseTime': pickup_to.strftime('%H:%M:00'),
            'PickupTime': pickup_from.strftime('%H:%M:00'),
            'RequestID': rand(0..999_999).to_s,
            'ServiceLevelID': '',
            'ShipmentTerms': '',
            'Stackable': false,
            'WebTrakUserID': options[:username]
          }
        }
      }

      save_request(request)
      request
    end

    def parse_rate_response(origin, destination, response)
      success = true
      message = ''

      raise Interstellar::ResponseError, pretty_error if response.blank?
        
      error = response.dig(:get_rating_response, :get_rating_result, :rating_output, :message)

      if !error.blank?
        if error.include?('do not service this lane')
          raise Interstellar::UnserviceableError, 'Incorrect ZIP code or no service available at origin and/or destination'
        end

        pretty_error = error.strip.gsub('can not', 'cannot')
        raise Interstellar::ResponseError, pretty_error
      end

      response = response.dig(:get_rating_response, :get_rating_result, :rating_output)
      raise Interstellar::ResponseError, pretty_error if response.blank?

      cost = response.dig(:standard_total_rate)&.sub('.', '')&.to_i
      raise Interstellar::ResponseError, 'Cost is blank' if cost.blank?

      transit_days = response.dig(:transit_days).to_i
      rate = RateEstimate.new(
        origin,
        destination,
        { scac: self.class.scac.upcase, name: self.class.name },
        :standard,
        currency: 'USD',
        estimate_reference: nil,
        total_cost: cost,
        total_price: cost,
        transit_days: transit_days,
        with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
      )

      RateResponse.new(
        success,
        message,
        response.to_hash,
        rates: [rate],
        response:,
        request: last_request
      )
    end

    # Tracking
  end
end
