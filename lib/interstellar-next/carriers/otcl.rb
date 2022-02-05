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

    protected

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
      response = HTTParty.get(request[:url])
      response.parsed_response if response&.parsed_response
    end

    def serviceable_states?(states)
      valid_states = %w[AZ CA CO ID NV OR UT WA]

      invalid_states = []
      states.each do |state|
        invalid_states << state unless valid_states.include?(state)
      end

      return true if invalid_states.blank?

      raise Interstellar::UnserviceableError, "No service to #{invalid_states.join(', ')}"
    end

    # Documents

    # Pickups

    # Rates

    def build_rate_request(shipment:)
      serviceable_accessorials?(shipment.accessorials)
      serviceable_states?([shipment.origin.state, shipment.destination.state])

      params = ''.dup
      params << 'packages='

      total_weight = shipment.packages.map { |p| p.pounds(:total) }.sum

      i = 1
      package_param_parts = []

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

          package_param_parts << parts.join(';')
        end
      end

      params << package_param_parts.join(',')

      build_request(:rates, { params: })
    end

    def parse_rate_response(shipment:, response:)
      raise Interstellar::ResponseError, 'API Error: Blank response' if response.blank?
      raise Interstellar::ResponseError, "API Error: #{response[:error]}" unless response[:error].blank?

      error = response.dig('OnTracRateResponse', 'Shipments', 'Shipment', 'Error')

      unless error.blank?
        raise Interstellar::UnserviceableError, error if error.downcase.include?('not serviced')

        raise Interstellar::ResponseError, "API Error: #{error}"
      end

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
        rates: [
          Rate.new(
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
        request: last_request,
        response:
      )
    end

    # Tracking
  end
end
