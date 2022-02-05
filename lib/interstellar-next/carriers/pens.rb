# frozen_string_literal: true

module Interstellar
  class PENS < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Peninsula Truck Lines'
    @@scac = 'PENS'

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(10_000, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(6, :feet)
    end

    def overlength_fees_require_tariff?
      false
    end

    def requirements
      %i[username password account]
    end

    # Documents

    # Rates
    def find_rates(shipment:)
      validate_packages(shipment.packages)

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit_soap(:rates, request))
    end

    def find_rates_implemented?
      true
    end

    # Tracking

    protected

    def commit_soap(action, request)
      Savon.client(
        wsdl: request_url(action),
        convert_request_keys_to: :lower_camelcase,
        env_namespace: :soap,
        element_form_default: :qualified
      ).call(
        @conf.dig(:api, :actions, action),
        message: request
      ).body
    end

    def parse_amount(amount)
      negative = amount.start_with?('-$') || amount.start_with?('-')

      %w[$ - ,].each do |char|
        amount = amount.sub(char, '')
      end

      return 0 if amount.blank?

      amount = (amount.to_f * 100).to_i
      return amount unless negative

      amount * -1
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domains, action)}#{@conf.dig(:api, :endpoints, action)}"
    end

    # Documents

    # Rates
    def build_rate_request(shipment:)
      raise UnserviceableError, 'Unable to quote accessorials over API' unless shipment.accessorials.blank?

      request = {
        accessorial_list: '', # TODO: Fix this!
        account: @options[:account],
        class_list: shipment.packages.map(&:freight_class).join(','),
        customer_type: @options[:customer_type].blank? ? 'B' : @options[:customer_type],
        destination_zip: shipment.destination.zip.to_s,
        none_palletized_mode: shipment.packages.map(&:packaging).map(&:pallet?).any?(false) ? 'Y' : 'N',
        origin_zip: shipment.origin.zip.to_s,
        password: @options[:password],
        plt_count_list: shipment.packages.map(&:quantity).join(','),
        plt_length_list: shipment.packages.map { |p| p.inches(:length).ceil }.join(','),
        plt_total_weight: shipment.packages.map { |p| p.pounds(:total).ceil }.join(','),
        plt_width_list: shipment.packages.map { |p| p.inches(:width).ceil }.join(','),
        user_id: @options[:username],
        weight_list: shipment.packages.map { |p| p.pounds(:total) }.join(',')
      }

      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:)
      raise ResponseError, 'API Error: Unknown response' if response.blank?

      error = response.dig(:create_pens_rate_quote_response, :create_pens_rate_quote_result, :errors, :message)

      unless error.blank?
        if error.include?('[RatingService.ValidateZipCodes]')
          raise Interstellar::UnserviceableError, 'Origin or destination has no service available'
        end

        raise ResponseError, "API Error: #{error}"
      end

      result = response.dig(:create_pens_rate_quote_response, :create_pens_rate_quote_result)

      raise ResponseError, 'API Error: Cost is blank' if result.dig(:quote, :gross_charge).blank?

      service_type = :standard
      api_service_type = result.dig(:quote, :transit_type)

      @conf.dig(:services, :mappable).each do |key, val|
        service_type = key if api_service_type.downcase.include?(val)
      end

      transit_days = service_type == :next_day_ltl ? 1 : nil # TODO: Detect correctly

      estimate_reference = result.dig('quote', 'quote_number')

      prices = []

      prices << Price.new(
        blame: :api,
        cents: parse_amount(result.dig(:quote, :gross_charge)),
        description: 'Charge based on class and weight'
      )

      accessorial_details = result.dig(:quote, :accessorial_detail)
      accessorial_details = [accessorial_details] if accessorial_details.is_a?(Hash)

      accessorial_details.each do |accessorial_detail|
        accessorial_item = accessorial_detail[:accessorial_item]

        prices << Price.new(
          blame: :api,
          cents: parse_amount(accessorial_item[:charge]),
          description: accessorial_item[:description]&.capitalize
        )
      end

      prices << Price.new(
        blame: :api,
        cents: parse_amount(result.dig(:quote, :discount_amount)),
        description: 'Discount'
      )

      prices << Price.new(
        blame: :api,
        cents: parse_amount(result.dig(:quote, :fsc_amount)),
        description: 'Fuel surcharge'
      )

      RateResponse.new(
        rates: [
          Rate.new(
            carrier: self,
            carrier_name: self.class.name,
            currency: 'USD',
            estimate_reference:,
            scac: self.class.scac.upcase,
            service_name: :standard,
            shipment:,
            prices:,
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
