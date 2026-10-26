module FreightKit
  module Carriers
    class TotalQualityLogistics < FreightKit::Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Cincinnati',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '55c06675-cf01-4657-8f57-eba4e50be0fd',
              postal_code: '45263',
              region_abbreviation: 'OH',
              street: 'PO Box 634558'
            )
          ]
        end

        def consider_bol_and_pod_documents_same? = true
        def id = '1e1dad85-44fb-44d8-9b13-09037d401f17'

        # Per carrier at 2023-02-13
        def mappable_accessorials
          {
            appointment_delivery: 'APPTDEL',
            inside_delivery: 'INPU',
            inside_pickup: 'INDEL',
            liftgate_delivery: 'LGDEL',
            liftgate_pickup: 'LGPU'
          }
        end

        def minimum_length_for_overlength_fees = Measured::Length.new(6, :feet)
        def name = 'Total Quality Logistics'
        def overlength_fees_require_tariff? = false
        def required_credential_types = %i[api]
        def requirements = %i[credentials]
        def scac = 'TQYL'
        def website_url = 'https://www.tql.com'
      end

      include FreightKit::Rateable
      include FreightKit::Trackable
      include FreightKit::Pickupable

      API = {
        domain: 'public.api.tql.com',
        endpoints: {
          rates: '/ltl/quotes',
          track: '/tracking/%TRACKING_NUMBER%',
          pickup: '/ltl/loads/tender',
          auth: '/identity/token'
        },
        methods: { rates: :post, track: :get, pickup: :post, auth: :post }
      }.freeze
      API_SCOPE = 'https://tqlidentity.onmicrosoft.com/services_combined/LTLQuotes.Tender'.freeze
      EVENTS = { types: { picked_up: 'Tendered', delivered: 'Delivered', out_for_delivery: 'In Transit' } }.freeze

      protected

      def build_access_token
        build_url(:auth)
        credentials = fetch_credential(:api)

        request_body = {
          username: credentials.username,
          password: credentials.password,
          grant_type: 'password',
          scope: API_SCOPE,
          client_id: credentials.api_key
        }

        request = build_request(:auth, query: request_body)
        response = commit(request)

        response['access_token']
      end

      def build_accessorials(shipment:)
        accessorials = []
        serviceable_accessorials?(shipment.accessorials)

        shipment.accessorials.map do |accessorial|
          next if mappable_accessorials.exclude?(accessorial)

          accessorials << mappable_accessorials[accessorial.to_sym]
        end

        accessorials
      end

      def build_commodities(shipment)
        shipment.packages.map do |package|
          unit_type = package.packaging.type.to_s
          {
            freightClassCode: package.freight_class,
            unitTypeCode: package.packaging.pallet? ? 'PLT' : unit_type.upcase,
            description: package.description,
            quantity: package.quantity.to_i,
            weight: package.pounds(:total).ceil.to_i,
            dimensionHeight: package.inches(:height).ceil.to_i,
            dimensionLength: package.inches(:length).ceil.to_i,
            dimensionWidth: package.inches(:width).ceil.to_i,
            isHazmat: package.hazmat?
          }
        end
      end

      def build_pickup_request(
        delivery_from:,
        delivery_to:,
        dispatcher:,
        pickup_from:,
        pickup_to:,
        scac:,
        service:,
        shipment:
      )
        origin = shipment.origin
        destination = shipment.destination
        shipper_phone = shipment.origin.contact.phone.delete('^0-9')
        receiver_phone = shipment.destination.contact.phone.delete('^0-9')

        build_request(
          :pickup,
          body: {
            scac:,
            serviceLevel: service.to_s.capitalize,
            shipmentDate: pickup_from.iso8601,
            commodities: build_commodities(shipment),
            accessorials: build_accessorials(shipment:),
            pickupDetails: {
              address1: origin.address1,
              postalCode: origin.postal_code.to_i,
              city: origin.city,
              state: origin.province.upcase,
              country: origin.country.code(:alpha3).value,
              contactName: origin.contact.name || 'Shipping',
              contactPhone: shipper_phone || '',
              stopName: origin.contact.name || 'Shipping',
              hoursOpen: pickup_from.strftime('%I:%M %p'),
              hoursClosed: pickup_to.strftime('%I:%M %p')
            },
            deliveryDetails: {
              address1: destination.address1,
              postalCode: destination.postal_code.to_i,
              city: destination.city,
              state: destination.province.upcase,
              country: destination.country.code(:alpha3).value,
              contactName: destination.contact.name || 'Receiving',
              contactPhone: receiver_phone || '',
              stopName: destination.contact.name || 'Receiving',
              hoursOpen: delivery_from.strftime('%I:%M %p'),
              hoursClosed: delivery_to.strftime('%I:%M %p')
            }
          }
        )
      end

      def build_rate_request(shipment:)
        origin = shipment.origin
        destination = shipment.destination

        build_request(
          :rates,
          body: {
            accessorials: build_accessorials(shipment:),
            pickLocationType: origin.type || 'Commercial',
            origin: {
              postalCode: origin.postal_code.to_i,
              city: origin.city,
              state: origin.province.upcase,
              country: origin.country.code(:alpha3).value
            },
            dropLocationType: destination.type || 'Commercial',
            destination: {
              postalCode: destination.postal_code.to_i,
              city: destination.city,
              state: destination.province.upcase,
              country: destination.country.code(:alpha3).value
            },
            shipmentDate: shipment.pickup_at.date_time_with_zone.iso8601,
            quoteCommodities: build_commodities(shipment)
          }.to_json
        )
      end

      def build_request(action, body: {}, query: {})
        fetch_credential(:api).api_key

        request = { url: build_url(action), method: API.dig(:methods, action), headers: {}, body:, query: }.compact

        request[:headers] = { 'Authorization' => "Bearer #{build_access_token}" } unless action == :auth

        save_request(request)
        request
      end

      def build_tracking_request(tracking_number)
        request = {
          url: build_url(:track).gsub('%TRACKING_NUMBER%', tracking_number.to_s),
          method: API.dig(:methods, :track),
          headers: { 'Authorization' => "Bearer #{build_access_token}" }
        }.compact

        save_request(request)
        request
      end

      def build_url(action) = "https://#{API[:domain]}#{API.dig(:endpoints, action)}"

      def commit(request)
        response = HTTPClient.request(
          request[:method],
          request[:url],
          headers: request[:headers].merge(subscription_key_headers),
          query: request[:query],
          body: request[:body]
        )

        parsed_response = JSON.parse(response.body)
        return parsed_response if [200, 201].include?(response.code)

        message = if parsed_response.is_a?(String)
                    parsed_response
                  else
                    parsed_response.dig('content', 'message').presence || "HTTP #{response.code}"
                  end

        raise FreightKit::ResponseError, message
      rescue JSON::ParserError => e
        raise FreightKit::InvalidCredentialsError if response.body.include?('Sorry, but we&#39;re having trouble signing you in')

        raise FreightKit::ResponseError, e.message
      end

      def parse_pickup_response(response)
        pickup_response = PickupResponse.new(request: last_request, response:)
        pickup_number = response.dig('content', 'poNumber')

        if pickup_number.blank?
          pickup_response.error = FreightKit::ResponseError.new('Unknown response')
          return pickup_response
        end

        pickup_response.pickup_number = pickup_number
        pickup_response
      end

      def parse_rate_response(shipment:, response:)
        rate_response = RateResponse.new(request: last_request, response:)

        if response.blank?
          rate_response.error = ResponseError.new('Unknown response')
          return rate_response
        end

        if response['statusCode'] != 201
          rate_response.error = ResponseError.new(response.dig('content', 'message'))
          return rate_response
        end

        rates = []

        response.dig('content', 'carrierPrices').each do |response_line|
          rate_in_cents = (response_line['customerRate'].to_f * 100).round
          rates << Rate.new(
            carrier_name: response_line['carrier'],
            carrier: self,
            currency: 'USD',
            estimate_reference: response_line['id'],
            prices: [Price.new(blame: :api, cents: rate_in_cents, description: response_line['CarrierName'])],
            scac: response_line['scac'],
            service_name: :standard,
            shipment:,
            transit_days: response_line['transitDays'],
            with_excessive_length_fees: rates_with_excessive_length_fees?
          )
        end

        rate_response.rates = rates
        rate_response
      end

      def parse_tracking_response(response)
        tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)

        actual_delivery_date = nil
        estimated_delivery_date = nil
        scheduled_delivery_date = nil
        ship_time = nil

        pickup_city, pickup_state = response['firstPick'].split(', ')
        drop_city, drop_state = response['lastDrop'].split(', ')
        country = ActiveUtils::Country.find('US') # Fallback To US. Country not provided in response
        receiver_location = Location.new(city: pickup_city, province: pickup_state, country:)
        shipper_location = Location.new(city: drop_city, province: drop_state, country:)

        tracking_number = response['poNumber']
        status = response['status']

        shipment_events = []

        response['trackingDetails'].each do |api_event|
          event = EVENTS[:types].key(api_event['status'])

          case event
          when :picked_up
            ship_time = api_event['time']
          when :delivered
            actual_delivery_date = api_event['time'].to_date
          end

          shipment_events << ShipmentEvent.new(
            date_time: api_event['time'],
            location: Location.new(city: api_event['city'], province: api_event['state'], country:),
            type_code: event
          )
        end

        tracking_response.assign_attributes(
          actual_delivery_date:,
          destination: receiver_location,
          estimated_delivery_date:,
          origin: shipper_location,
          scheduled_delivery_date:,
          ship_time:,
          shipment_events:,
          status:,
          tracking_number:
        )
      end

      def subscription_key_headers
        { 'Ocp-Apim-Subscription-Key' => fetch_credential(:api).account, 'Content-Type' => 'application/json' }
      end
    end
  end
end
