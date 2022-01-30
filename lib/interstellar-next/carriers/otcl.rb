# frozen_string_literal: true

module Interstellar
  class OTCL < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'OnTrac'
    @@scac = 'OTCL'

    XML_HEADERS = {
      'Accept': 'application/xml',
      'charset': 'utf-8',
      'Content-Type': 'application/xml'
    }.freeze

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(150, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(6, :feet)
    end

    def overlength_fees_require_tariff?
      false
    end

    # Override Carrier#serviceable_accessorials? since we have separate delivery/pickup accessorials
    def serviceable_accessorials?(accessorials)
      return true if accessorials.blank?

      if !self.class::REACTIVE_FREIGHT_CARRIER ||
         !@conf.dig(:accessorials, :mappable) ||
         !@conf.dig(:accessorials, :unquotable) ||
         !@conf.dig(:accessorials, :unserviceable)
        raise NotImplementedError, "#{self.class.name}: #serviceable_accessorials? not supported"
      end

      serviceable_accessorials = @conf.dig(:accessorials, :mappable, :delivery).keys +
                                 @conf.dig(:accessorials, :mappable, :pickup).keys +
                                 @conf.dig(:accessorials, :unquotable)
      serviceable_count = (serviceable_accessorials & accessorials).size

      unserviceable_accessorials = @conf.dig(:accessorials, :unserviceable)
      unserviceable_count = (unserviceable_accessorials & accessorials).size

      if serviceable_count != accessorials.size || !unserviceable_count.zero?
        raise Interstellar::UnserviceableError, "#{self.class.name}: Some accessorials unserviceable"
      end

      true
    end

    # Documents

    # Pickups

    def pickup_number_is_tracking_number?
      true
    end

    # Rates

    def find_rates(shipment:)
      validate_packages(shipment.packages)

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit(request))
    end

    def find_rates_implemented?
      true
    end

    def find_rates_with_declared_value?
      true
    end

    # Tracking

    def find_tracking_info(tracking_number, *)
      request = build_tracking_request(tracking_number)
      parse_tracking_response(commit(request))
    end

    def find_tracking_info_implemented?
      true
    end

    protected

    def build_accessorials(accessorials)
      delivery_accessorials = []
      pickup_accessorials = []

      unless accessorials.blank?
        serviceable_accessorials?(accessorials)
        accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            if @conf.dig(:accessorials, :mappable, :pickup).include?(a)
              pickup_accessorials << @conf.dig(:accessorials, :mappable, :pickup)[a]
            elsif delivery_accessorials << @conf.dig(:accessorials, :mappable, :delivery)[a]
            end
          end
        end
      end

      if !delivery_accessorials.blank? && delivery_accessorials.include?('RDE')
        # Remove duplicate delivery appointment accessorial when residential delivery (included with RDE)
        delivery_accessorials -= ['ADE']
      end

      if !pickup_accessorials.blank? && pickup_accessorials.include?('RPU')
        # Remove duplicate pickup appointment accessorial when residential pickup (included with RPU)
        pickup_accessorials -= ['APP']
      end

      # API doesn't like empty arrays
      delivery_accessorials = nil if delivery_accessorials.blank?
      pickup_accessorials = nil if pickup_accessorials.blank?

      [pickup_accessorials&.uniq, delivery_accessorials&.uniq]
    end

    def build_url(action, options = {})
      env = @test_mode ? :test : :production

      url = "https://#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, env, action)}"
      url = url.gsub('%ACCOUNT_NUMBER%', @options[:account])

      url += "?pw=#{@options[:password]}"
      url << "&#{options[:params]}" unless options[:params].blank?

      url
    end

    def build_request(action, options = {})
      request = {
        url: build_url(action, options),
        headers: XML_HEADERS,
        method: @conf.dig(:api, :methods, action)
      }

      save_request(request)
      request
    end

    def commit(request)
      response = HTTParty.get(request[:url], debug_output: $stdout)
      response.parsed_response if response&.parsed_response
    end

    # Documents

    # Pickups

    # Rates

    def build_rate_request(shipment:)
      serviceable_accessorials?(shipment.accessorials)

      params = ''.dup
      params << 'packages='

      total_weight = shipment.packages.map { |p| p.pounds(:total) }.sum

      i = 1
      shipment.packages.each do |package|
        package.quantity.times do
          declared_value = if shipment.declared_value_cents.blank?
                             0
                           else
                             shipment.declared_value_cents.to_f * (package.pounds(:each) / total_weight)
                           end

          declared_value = declared_value.to_s
          palletized = !shipment.packages.map(&:packaging).map(&:pallet?).any?(false)
          service = palletized ? 'H' : 'C'

          parts = []

          parts << "ID#{i}"
          parts << shipment.origin.zip
          parts << shipment.destination.zip
          parts << shipment.accessorials.include?(:residential_delivery) ? 'true' : 'false'
          parts << '0'
          parts << 'false' # Staurday delivery
          parts << declared_value
          parts << package.pounds(:each)
          parts << "#{package.inches(:length).ceil}X#{package.inches(:width).ceil}X#{package.inches(:height).ceil}"
          parts << service
          parts << '0' # not a letter
          parts << '0' # always 0 per documentation

          params << "{#{parts.join(';')}}"
        end
      end

      build_request(:rates, { params: })
    end

    def parse_rate_response(shipment:, response:)
      raise Interstellar::ResponseError, 'API Error: Blank response' if response.blank?
      raise Interstellar::ResponseError, "API Error: #{error} if response.blank?" unless response[:error].blank?

      rate = response.dig('OnTracRateResponse', 'Shipments', 'Shipment', 'Rates', 'Rate')
      raise Interstellar::ResponseError, 'API Error: Blank response' if rate.blank?

      rate_estimates = []

      cost = rate['TotalCharge']&.to_f
      raise Interstellar::ResponseError, 'API Error: Cost is empty' if cost.blank?

      cost = (cost * 100).to_i
      transit_days = rate['TransitDays'].to_i
      service = case rate['Service']
                when 'C'
                  :standard
                when 'H'
                  :standard
                else
                  :standard
                end

      RateResponse.new(
        true,
        '',
        response,
        rates: [
          RateEstimate.new(
            carrier: self,
            carrier_name: self.class.name,
            currency: 'USD',
            scac: self.class.scac.upcase,
            service_name: service,
            shipment:,
            total_price: cost,
            transit_days:,
            with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
          )
        ],
        response:,
        request: last_request
      )
    end

    # Tracking
  end
end
