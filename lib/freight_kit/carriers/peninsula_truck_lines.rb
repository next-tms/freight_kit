module FreightKit
  module Carriers
    class PeninsulaTruckLines < FreightKit::Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Auburn',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'cec1afb8-8fa2-4e4d-b8be-4e9bd5c894cd',
              postal_code: '98071',
              region_abbreviation: 'WA',
              street: 'PO Box 587'
            )
          ]
        end

        def contacts
          [Contact.new(department: 'Main', id: '4db2550c-8633-4a79-b71d-e1b98a747cb5', phone: '+12539292000')]
        end

        def headquarters
          Address.new(
            city: 'Federal Way',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '4579fa1e-9547-4d92-97d2-0272e14ffa6a',
            postal_code: '98003-6335',
            region_abbreviation: 'WA',
            street: '33455 6th Ave S'
          )
        end

        def id = 'ef9f5115-653e-400f-a098-be8d54cd0953'
        def legal_name = 'Peninsula Truck Lines Inc'
        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(6, :feet)
        def name = 'Peninsula Truck Lines'
        def overlength_fees_require_tariff? = false
        def rates_with_excessive_length_fees? = false
        def required_credential_types = %i[api]
        def requirements = %i[credentials]
        def scac = 'PENS'
        def services = %i[next_day_ltl standard]
        def us_dot_number = 8_329
        def us_mc_number = 113_165
      end

      include FreightKit::Rateable

      API = {
        actions: { rates: :create_pens_rate_quote },
        domains: { rates: 'www.peninsulatruck.com' },
        endpoints: { rates: '/webservices/pensrater.asmx?wsdl' },
        soap: { namespaces: { rates: 'http://peninsulatruck.com/WebServices' } },
        use_ssl: { rates: true }
      }.freeze
      SERVICE_CODES = { next_day_ltl: 'next business day' }.freeze

      # Documents

      # Tracking

      protected

      # Rates
      def build_rate_request(shipment:)
        raise UnserviceableError, 'Unable to quote accessorials over API' if shipment.accessorials.present?

        api_credentials = fetch_credential(:api)

        request = {
          accessorial_list: '', # TODO: Fix this!
          account: api_credentials.account,
          class_list: shipment.packages.map(&:freight_class).join(','),
          customer_type: 'B',
          destination_zip: shipment.destination.postal_code.to_s,
          none_palletized_mode: shipment.packages.map(&:packaging).map(&:pallet?).any?(false) ? 'Y' : 'N',
          origin_zip: shipment.origin.postal_code.to_s,
          password: api_credentials.password,
          plt_count_list: shipment.packages.map(&:quantity).join(','),
          plt_length_list: shipment.packages.map { |p| p.inches(:length).ceil }.join(','),
          plt_total_weight: shipment.packages.map { |p| p.pounds(:total).ceil }.join(','),
          plt_width_list: shipment.packages.map { |p| p.inches(:width).ceil }.join(','),
          user_id: api_credentials.username,
          weight_list: shipment.packages.map { |p| p.pounds(:total) }.join(',')
        }

        save_request(request)
        request
      end

      def commit(action, request)
        client_args = {
          wsdl: request_url(action),
          convert_request_keys_to: :lower_camelcase,
          env_namespace: :soap,
          element_form_default: :qualified
        }

        call_args = { message: request }

        ::FreightKit::SoapClient.new(
          carrier: self,
          action:,
          client_args:,
          call_args:,
          soap_operation: API.dig(:actions, action)
        ).call
      end

      def parse_amount(amount)
        negative = amount.start_with?('-$') || amount.start_with?('-')

        ['$', '-', ','].each do |char|
          amount = amount.sub(char, '')
        end

        return 0 if amount.blank?

        amount = (amount.to_f * 100).to_i
        return amount unless negative

        amount * -1
      end

      def parse_rate_response(shipment:, response:)
        rate_response = RateResponse.new(request: last_request, response:)

        if response.blank?
          rate_response.error = ResponseError.new('Unknown response')
          return rate_response
        end

        error = response.dig(:create_pens_rate_quote_response, :create_pens_rate_quote_result, :errors, :message)

        if error.present?
          if error.include?('[RatingService.ValidateZipCodes]')
            rate_response.error = UnserviceableError.new('Origin or destination has no service available')
          end

          rate_response.error = ResponseError.new(error) if rate_response.error.blank?
          return rate_response
        end

        result = response.dig(:create_pens_rate_quote_response, :create_pens_rate_quote_result)

        if result.dig(:quote, :gross_charge).blank?
          rate_response.error = ResponseError.new('Cost is blank')
          return rate_response
        end

        service_type = :standard
        api_service_type = result.dig(:quote, :transit_type)

        SERVICE_CODES.each do |key, val|
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

        rate = Rate.new(
          carrier: self,
          carrier_name: name,
          currency: 'USD',
          estimate_reference:,
          scac:,
          service_name: :standard,
          shipment:,
          prices:,
          transit_days:,
          with_excessive_length_fees: rates_with_excessive_length_fees?
        )

        rate_response.rates = [rate]
        rate_response
      end

      def request_url(action)
        scheme = API.dig(:use_ssl, action) ? 'https://' : 'http://'
        "#{scheme}#{API.dig(:domains, action)}#{API.dig(:endpoints, action)}"
      end

      # Tracking
    end
  end
end
