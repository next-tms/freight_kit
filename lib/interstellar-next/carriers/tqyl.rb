# frozen_string_literal: true

module Interstellar
  class TQYL < Interstellar::Carrier
    class << self
      def minimum_length_for_overlength_fees
        Measured::Length.new(6, :feet)
      end

      def overlength_fees_require_tariff?
        false
      end

      def required_credential_types
        %i[api]
      end

      def requirements
        %i[credentials]
      end

      def pod_implemented?
        true
      end

      def scanned_bol_implemented?
        true
      end

      def create_pickup_implemented?
        true
      end
    end

    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Total Quality Logistics'
    @@scac = 'TQYL'

    API_SCOPE = "https://tqlidentity.onmicrosoft.com/services_combined/LTLQuotes.Tender".freeze

    include Interstellar::Rateable
    include Interstellar::Trackable

    protected

    def build_url(action)
      "https://#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
    end

    def build_request(action, body: {}, query: {})
      api_key = fetch_credential(:api).api_key

      request = {
        url: build_url(action),
        method: @conf.dig(:api, :methods, action),
        headers: {},
        body:,
        query:,
      }.compact

      request[:headers] = { "Authorization" => "Bearer #{build_access_token}"} unless action == :auth

      save_request(request)
      request
    end

    def commit(request)
      
      response = HTTParty.send(
        request[:method],
        request[:url],
        headers: request[:headers].merge(subscription_key_headers),
        query: request[:query],
        body: request[:body],
        debug_output: $stdout
      )

      unless [200, 201].include? response.code
        message = begin
          parsed_response = JSON.parse(response.body)
          if parsed_response.is_a?(String)
            parsed_response
          else
            parsed_response.dig('content', 'message') || "HTTP #{response.code}"
          end
        rescue JSON::ParserError
          "HTTP #{response.code}"
        end

        raise Interstellar::ResponseError, message
      end

      
      JSON.parse(response.body)
    end

    def build_access_token
      cached_token = Rails.cache.read('tqyl_access_token')
      return cached_token if cached_token

      url = build_url(:auth)
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

      token = response['access_token']
      Rails.cache.write('tqyl_access_token', token, expires_in: 30.minutes)

      token
    end

    def subscription_key_headers
      { 
        "Ocp-Apim-Subscription-Key" => fetch_credential(:api).account,
        'Content-Type' => 'application/json'
      }
    end

    # Tracking

    def build_tracking_request(tracking_number)
      
      request = {
        url: build_url(:track).gsub("%TRACKING_NUMBER%", tracking_number.to_s),
        method: @conf.dig(:api, :methods, :track),
        headers: { "Authorization" => "Bearer #{build_access_token}"},
      }.compact
 
      save_request(request)
      request
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
        event = @conf.dig(:events, :types).key(api_event['status'])

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

    # Rates

    def build_accessorials(shipment:)
      accessorials = []
      serviceable_accessorials?(shipment.accessorials)

      shipment.accessorials.map do |accessorial|
        next unless @conf.dig(:accessorials, :mappable)&.include?(accessorial)

        accessorials << @conf.dig(:accessorials, :mappable, accessorial.to_sym)
      end

      accessorials
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
          quoteCommodities: shipment.packages.map do |package|

            unit_type = package.packaging.type.to_s
            {
              freightClassCode: package.freight_class,
              unitTypeCode: unit_type == 'pallet' ? 'PLT' : unit_type.upcase,
              description: package.description,
              quantity: package.quantity.to_i,
              weight: package.pounds(:total).ceil.to_i,
              dimensionHeight: package.inches(:height).ceil.to_i,
              dimensionLength: package.inches(:length).ceil.to_i,
              dimensionWidth: package.inches(:width).ceil.to_i,
              isHazmat: package.hazmat
            }
          end
        }.to_json
      )
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
        rates <<  Rate.new(
          carrier_name: response_line['carrier'],
          carrier: self,
          currency: 'USD',
          estimate_reference: response_line['id'],
          prices: [
            Price.new(blame: :api, cents: response_line['customerRate'], description: response_line['CarrierName'])
          ],
          scac: response_line['scac'],
          service_name: :standard,
          shipment:,
          transit_days: response_line['transitDays'],
          with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
        )
      end

      rate_response.rates = rates
      rate_response
    end
  end
end
