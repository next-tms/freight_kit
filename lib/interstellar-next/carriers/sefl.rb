# frozen_string_literal: true

module Interstellar
  class SEFL < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Southeastern Freight Lines'
    @@scac = 'SEFL'

    JSON_HEADERS = {
      'Accept': 'application/json',
      'charset': 'utf-8',
      'Content-Type' => 'application/x-www-form-urlencoded'
    }.freeze

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
    def find_rates(shipment:)
      validate_packages(shipment.packages)

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit(request))
    end

    def find_rates_implemented?
      true
    end

    # Tracking

    protected

    def build_url(action, options = {})
      options = @options.merge(options)
      "#{base_url}#{@conf.dig(:api, :endpoints, action)}"
    end

    def base_url
      "https://#{@conf.dig(:api, :domain)}"
    end

    def auth_header(options = {})
      options = @options.merge(options)
      if !options[:username].blank? && !options[:password].blank?
        auth = Base64.strict_encode64("#{options[:username]}:#{options[:password]}")
        return { 'Authorization': "Basic #{auth}" }
      end

      {}
    end

    def build_request(action, options = {})
      options = @options.merge(options)
      headers = JSON_HEADERS
      headers = headers.merge(auth_header)
      headers = headers.merge(options[:headers]) unless options[:headers].blank?
      body = URI.encode_www_form(options[:body]) unless options[:body].blank?

      request = {
        url: options[:url].blank? ? build_url(action, options) : options[:url],
        headers:,
        method: @conf.dig(:api, :methods, action),
        body:
      }

      save_request(request)
      request
    end

    def commit(request)
      url = request[:url]
      headers = request[:headers]
      method = request[:method]
      body = request[:body]

      case method
      when :post
        HTTParty.post(url, headers:, body:)
      else
        HTTParty.get(url, headers:)
      end
    end

    # Documents

    # Rates
    def build_rate_request(shipment:)
      accessorials = []
      unless shipment.accessorials.blank?
        serviceable_accessorials?(shipment.accessorials)
        shipment.accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << @conf.dig(:accessorials, :mappable)[a]
          end
        end
      end

      longest_dimension = shipment.packages.map { |p| [p.width(:inches), p.length(:inches)].max }.max.ceil
      accessorials << 'chkOD' if longest_dimension >= 96

      accessorials = accessorials.uniq
      pickup_on = Date.current
      shipment_description = shipment.packages.map(&:description).reject(&:blank?).uniq.join(', ')
      shipment_description = 'Freight All Kinds' if shipment_description.blank?

      body = {
        allowSpot: longest_dimension >= 120 ? 'Y' : 'N',
        CustomerAccount: @options[:account].to_i.to_s.rjust(9, '0'),
        CustomerCity: @options.dig(:customer_address, :city),
        CustomerName: @options[:customer_name],
        CustomerState: @options.dig(:customer_address, :state),
        CustomerStreet: @options.dig(:customer_address, :street),
        CustomerZip: @options.dig(:customer_address, :zip_code),
        Description: shipment_description,
        DestCountry: 'U',
        DestinationCity: shipment.destination.city,
        DestinationState: shipment.destination.state,
        DestinationZip: shipment.destination.zip,
        DimsOption: 'I',
        EmailAddress: @options[:customer_email].blank? ? 'unknown@fake.fake' : @options[:customer_email],
        Option: 'T',
        OrigCountry: 'U',
        OriginCity: shipment.origin.city,
        OriginState: shipment.origin.state,
        OriginZip: shipment.origin.zip,
        PickupDay: pickup_on.strftime('%_d'),
        PickupMonth: pickup_on.strftime('%_m'),
        PickupYear: pickup_on.strftime('%Y'),
        rateXML: 'Y',
        returnX: 'Y',
        Terms: 'P'
      }

      if longest_dimension >= 96
        body = body.deep_merge(
          {
            ODLength: longest_dimension,
            ODLengthUnit: 'I'
          }
        )
      end

      cubic_ft_required = shipment.destination.state.upcase == 'PR'

      i = 0
      shipment.packages.each do |package|
        package.quantity.times do
          i += 1

          body = body.deep_merge({ "Class#{i}": package.freight_class.to_s.sub('.', '').to_i })
          body = body.deep_merge({ "Description#{i}": package.description || 'Freight' })
          body = body.deep_merge({ "PieceLength#{i}": package.length(:in).ceil })
          body = body.deep_merge({ "PieceWidth#{i}": package.width(:in).ceil })
          body = body.deep_merge({ "PieceHeight#{i}": package.height(:in).ceil })
          body = body.deep_merge({ "Weight#{i}": package.pounds(:each).ceil })

          body = body.deep_merge({ "CubicFt#{i}": package.cubic_ft(:each) }) if cubic_ft_required
        end
      end

      body = body.deep_merge({ accessorial: 'on' }) unless accessorials.blank?

      request = build_request(:rates, body:)
      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:, tries: 0)
      raise Interstellar::ResponseError, "API Error: Timeout after #{tries * 5} seconds" if tries > 10

      if response.body.blank?
        raise Interstellar::InvalidCredentialsError if response.code == 401

        raise Interstellar::ResponseError
      end

      begin
        response = JSON.parse(response.body)
      rescue JSON::ParserError
        sleep(5)
        parse_rate_response(shipment:, response:, tries: tries + 1)
      end

      error = response['errorMessage']
      if error.include?('one point must be directly serviced')
        raise Interstellar::UnserviceableError, error.sub(' by SEFL.', '')
      else
        raise Interstellar::ResponseError, error
      end

      url = response['detailQuoteLocation'].gsub('\\', '')
      request = build_request(:get_rate, url:)
      save_request(request)
      response = commit(request)

      if response.body.blank?
        raise Interstellar::InvalidCredentialsError if response.code == 401

        raise Interstellar::ResponseError
      end

      response = JSON.parse(response.body)
      raise Interstellar::ResponseError if response.blank?

      error = response['errorMessage']
      raise Interstellar::ResponseError, "API Error: #{error}" unless error.blank?

      cost = response['rateQuote']&.sub('.', '')&.to_i
      raise Interstellar::ResponseError, 'API Error: Cost is empty' if response.blank?

      estimate_reference = response['quoteNumber']
      transit_days = response['transitTime'].to_i

      rate_estimates = [
        RateEstimate.new(
          shipment.origin,
          shipment.destination,
          { scac: self.class.scac.upcase, name: self.class.name },
          :standard,
          transit_days:,
          estimate_reference:,
          total_cost: cost,
          total_price: cost,
          currency: 'USD',
          with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
        )
      ]

      RateResponse.new(
        success,
        message,
        response.to_hash,
        rates: rate_estimates,
        response:,
        request: last_request
      )
    end

    # Tracking
  end
end
