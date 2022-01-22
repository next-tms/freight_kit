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
      ).body.to_json
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
        class_list: shipment.packages.map(&:quantity).join(','),
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
      success = true
      message = ''

      if !response
        success = false
        message = 'API Error: Unknown response'
      else
        response = JSON.parse(response)
        error = response.dig('create_pens_rate_quote_response', 'create_pens_rate_quote_result', 'errors', 'message')
        if !error.blank?
          success = false
          message = error
        else
          result = response.dig('create_pens_rate_quote_response', 'create_pens_rate_quote_result')

          service_type = :standard
          api_service_type = result.dig('quote', 'transit_type')
          @conf.dig(:services, :mappable).each do |key, val|
            service_type = key if api_service_type.downcase.include?(val)
          end

          cost = result.dig('quote', 'gross_charge').sub(',', '').sub('.', '').to_i
          transit_days = service_type == :next_day_ltl ? 1 : nil # TODO: Detect correctly
          estimate_reference = result.dig('quote', 'quote_number')
          if cost
            rate_estimates = [
              RateEstimate.new(
                carrier: self,
                carrier_name: self.class.name,
                currency: 'USD',
                estimate_reference:,
                scac: self.class.scac.upcase,
                service_name: :standard,
                shipment:,
                total_price: cost,
                transit_days:,
                with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
              )
            ]
          else
            success = false
            message = 'API Error: Cost is emtpy'
          end
        end
      end

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
