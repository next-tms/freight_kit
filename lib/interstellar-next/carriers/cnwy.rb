# frozen_string_literal: true

module Interstellar
  class CNWY < Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'XPO Logistics'
    @@scac = 'CNWY'

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

    def requirements
      %i[username password account]
    end

    # Documents

    # Pickups

    # Rates

    def find_rates(shipment:)
      begin
        validate_packages(shipment.packages)
      rescue UnserviceableError => e
        return RateResponse.new(error: e)
      end

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit_soap(:rates, request))
    end

    def find_rates_implemented?
      true
    end

    # Tracking

    protected

    def build_headers
      { 'x-api-key': @options[:password] }
    end

    def build_xpoauthorization_request
      {
        client_id
        client_secret
        grant_type: 'client_credentials',
        scope
      }
    end

    def commit(request)
      url = request[:url]
      headers = build_headers
      method = request[:method]
      body = request[:body]

      response = case method
                 when :post
                   HTTParty.post(url, headers:, body:, debug_output: $stdout)
                 else
                   HTTParty.get(url, headers:, debug_output: $stdout)
                 end

      raise Interstellar::ResponseError, "HTTP #{response.code}" unless response.code == 200

      return response unless response.headers.content_type == 'application/json'

      json = JSON.parse(response.body)
      error = json.is_a?(Array) ? nil : json['errorMessage']

      return json if error.blank?

      raise Interstellar::InvalidCredentialsError, error if error.downcase.include?('not authorized')
      raise Interstellar::InvalidCredentialsError, error if error.downcase.include?('shipper client does not exist')
      raise Interstellar::ShipmentNotFoundError, error if error.downcase.include?('no history found')
      raise Interstellar::UnserviceableError, error if error.downcase.include?('not serviced')

      raise Interstellar::ResponseError, error
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domains, action)}#{@conf.dig(:api, :endpoints, action)}"
    end

    def xpoauthorization
      return @xpoauthorization if @xpoauthorization

      request = build_xpoauthorization_request
    end

    # Documents

    # Rates

    def build_rate_request(shipment:)
      service_delivery_options = [
        # API calls this invalid now
        # service_options: { service_code: 'SS' }
      ]

      unless shipment.accessorials.blank?
        serviceable_accessorials?(shipment.accessorials)
        shipment.accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            service_delivery_options << { service_options: { service_code: @conf.dig(:accessorials, :mappable)[a] } }
          end
        end
      end

      shipment.packages.each do |package|
        longest_dimension = [package.width(:inches), package.length(:inches)].max.ceil

        next unless longest_dimension > 96

        package.quantity.times do
          if longest_dimension >= 240
            service_delivery_options << { service_options: { service_code: 'EXX' } }
          elsif longest_dimension >= 144
            service_delivery_options << { service_options: { service_code: 'EXL' } }
          elsif longest_dimension >= 96
            service_delivery_options << { service_options: { service_code: 'EXM' } }
          end
        end
      end

      shipment_detail = []
      shipment_box_count = 0
      shipment_pallet_count = 0

      shipment.packages.each do |package|
        if package.packaging.type == 'pallet'
          shipment_pallet_count += package.quantity
        else
          shipment_box_count += package.quantity
        end

        package.quantity.times do
          shipment_detail << {
            'ActualClass' => package.freight_class,
            'Weight' => package.pounds(:each).ceil
          }
        end
      end

      request = {
        'request' => {
          account: @options[:account],
          destination_zip: shipment.destination.postal_code.gsub(/\s+/, '').upcase,
          # :linear_feet => linear_ft(packages),
          origin_type: 'B', # O for shipper, I for consignee, B for third party
          origin_zip: shipment.origin.postal_code.gsub(/\s+/, '').upcase,
          pallet_count: shipment_pallet_count,
          payment_type: 'P', # prepaid
          pieces: shipment_box_count,
          service_delivery_options:,
          shipment_details: { shipment_detail: }
        }
      }

      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:)
      rate_response = RateResponse.new(request: last_request, response:)

      if response.blank?
        rate_response.error = ResponseError.new('Unknown response')
        return rate_response
      end

      unless response[:error].blank?
        ['no standard service', 'not in the standard pickup area'].each do |message|
          if response[:error].downcase.include?(message)
            rate_response.error = UnserviceableError.new(response[:error])
            return rate_response
          end
        end

        rate_response.error = ResponseError.new(response[:error])
        return rate_response
      end

      result = response.dig(:rate_quote_by_account_response, :rate_quote_by_account_result)

      if result[:net_charge].blank?
        rate_response.error = ResponseError.new('Cost is empty')
        return rate_response
      end

      estimate_reference = result.dig(:quote_number)
      rate_details = result.dig(:rate_details, :quote_detail)
      transit_days = result.dig(:routing_info, :estimated_transit_days).to_i

      prices = []

      rate_details.each do |rate_detail|
        if rate_detail[:description].blank?
          prices << Price.new(
            blame: :api,
            cents: parse_amount(rate_detail[:charge]),
            description: 'Freight'
          )

          next
        end

        prices << Interstellar::Price.new(
          blame: :api,
          cents: parse_amount(rate_detail[:charge]),
          description: rate_detail[:description]&.capitalize
        )
      end

      rate = Rate.new(
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

      rate_response.rates = [rate]
      rate_response
    end

    # Tracking
  end
end
