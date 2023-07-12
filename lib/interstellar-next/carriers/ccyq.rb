# frozen_string_literal: true

module Interstellar
  class CCYQ < Interstellar::Carrier
    class << self
      def minimum_length_for_overlength_fees
        Measured::Length.new(6, :feet)
      end

      def overlength_fees_require_tariff?
        false
      end

      def required_credential_types
        %i[api_key api_proxy]
      end

      def requirements
        %i[credentials]
      end
    end

    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'CrossCountry Freight Solutions'
    @@scac = 'CCYQ'

    JSON_HEADERS = {
      Accept: 'application/json',
      charset: 'utf-8',
      'Content-Type' => 'application/json'
    }.freeze

    include Interstellar::Rateable
    include Interstellar::Trackable
    include Interstellar::Documentable
    include Interstellar::Pickupable

    protected

    def build_url(action)
      "https://#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
    end

    def build_request(action, body: {}, query: {})
      api_key = fetch_credential(:api_key).api_key
      proxy_url = fetch_credential(:api_proxy).proxy_url

      request = {
        url: build_url(action),
        headers: { APIKEY: api_key },
        method: @conf.dig(:api, :methods, action),
        body:,
        query:,
        proxy_url:
      }.compact

      save_request(request)
      request
    end

    def commit(_action, request)
      proxy_uri = URI.parse(request[:proxy_url])

      response = HTTParty.send(
        request[:method],
        request[:url],
        headers: request[:headers].merge(JSON_HEADERS),
        body: request[:body],
        query: request[:query],
        http_proxyaddr: proxy_uri.host,
        http_proxyport: proxy_uri.port.to_s,
        http_proxyuser: proxy_uri.user,
        http_proxypass: proxy_uri.password,
        debug_output: $stdout
      )

      unless response.code == 200
        message = begin
          JSON.parse(response.body)['Message'] || "HTTP #{response.code}"
        rescue JSON::ParserError
          "HTTP #{response.code}"
        end

        raise Interstellar::ResponseError, message
      end

      JSON.parse(response.body)
    end

    # Documents

    def parse_document_response(type, tracking_number)
      # Tracking Endpoint returns Images for the Shipment
      request = build_request(:track, query: { ReferenceNum: tracking_number })
      response = commit(type, request)

      document_response = DocumentResponse.new

      unless response
        document_response.error = DocumentNotFoundError.new
        return document_response
      end

      # API response sometimes returns an array
      response = response.first if response.is_a?(Array)
      document = response['Images'].find { |image| image['DocumentType'] == type.upcase }

      unless document
        document_response.error = DocumentNotFoundError.new
        return document_response
      end

      decoded_pdf_data = Base64.decode64 document['Content']
      document_response.assign_attributes(content_type: 'application/pdf', data: decoded_pdf_data)

      document_response
    end

    # Tracking

    def build_tracking_request(tracking_number)
      build_request(:track, query: { ReferenceNum: tracking_number })
    end

    def parse_tracking_response(response)
      tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)

      # TODO
    end

    # Pickups

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

      dispatcher_phone = dispatcher.phone.delete('^0-9')
      receiver_phone = shipment.destination.contact.phone.delete('^0-9')

      build_request(
        :pickup,
        body: {
          PickupAddress: {
            Name: shipment.origin.contact.company_name || shipment.destination.origin.name,
            Address1: shipment.origin.address1,
            Address2: '',
            City: shipment.origin.city,
            State: shipment.origin.province,
            Zip: shipment.origin.postal_code.to_s,
            Phone: dispatcher_phone.presence || '',
            Contact: shipment.origin.contact.name,
            Country: shipment.origin.country.code(:alpha2).value
          },
          DeliveryAddress: {
            Name: shipment.destination.contact.company_name || shipment.destination.contact.name,
            Address1: shipment.destination.address1,
            Address2: '',
            City: shipment.destination.city,
            State: shipment.destination.province,
            Zip: shipment.destination.postal_code.to_s,
            Phone: receiver_phone || '',
            Contact: shipment.destination.contact.name,
            Country: shipment.destination.country.code(:alpha2).value
          },
          PickupSchedule: {
            After: pickup_from.iso8601,
            Before: pickup_to.iso8601,
            AppointmentRequired: false,
            AppointmentMade: false
          },
          TotalWeight: shipment.packages.sum { |p| p.pounds(:total).ceil },
          TotalUnits: shipment.packages.sum(&:quantity),
          TotalBills: 1,
          # TODO: Update with actual value: TotalBills desc =>
          # Total number of freight bills that will be picked up
          TestFlag: false
        }.to_json
      )
    end

    def parse_pickup_response(response)
      pickup_response = PickupResponse.new(request: last_request, response:)
      pickup_number = response['FreightBillNum']

      if pickup_number.blank?
        pickup_response.error = Interstellar::ResponseError.new('Unknown response')
        return pickup_response
      end

      pickup_response.pickup_number = pickup_number
      pickup_response
    end

    # Rates

    def build_accessorials(shipment:)
      accessorials = []
      serviceable_accessorials?(shipment.accessorials)

      accessorials << { Code: 'HAZMAT', Factor: 1 } if shipment.hazmat?

      shipment.packages.each do |package|
        longest_dimension = [package.width(:inches), package.length(:inches)].max.ceil

        next unless longest_dimension >= 96

        package.quantity.times do
          accessorials << { Code: 'EXLEN', Factor: longest_dimension }
        end
      end

      shipment.accessorials.map do |accessorial|
        next if @conf.dig(:accessorials, :unquotable)&.include?(accessorial)

        accessorials << { Code: @conf.dig(:accessorials, :mappable, accessorial.to_sym), Factor: 1 }
      end

      accessorials
    end

    def build_rate_request(shipment:)
      build_request(
        :rates,
        body: {
          Orig: shipment.origin.postal_code,
          Dest: shipment.destination.postal_code,
          Accesorials: build_accessorials(shipment:),
          Details: shipment.packages.map do |package|
            {
              Height: package.inches(:height).ceil.to_f,
              Length: package.inches(:length).ceil.to_f,
              Width: package.inches(:width).ceil.to_f,
              Units: package.quantity.to_i,
              Class: package.freight_class.to_f,
              Weight: package.pounds(:total).ceil.to_f
            }
          end
        }.to_json
      )
    end

    def parse_rate_response(shipment:, response:)
      rate_response = RateResponse.new(request: last_request, response:)

      if response.blank?
        rate_response.error = ResponseError.new('API Error: Unknown response')
        return rate_response
      end

      if response['Message'].include?('Quotes between these points are not available')
        rate_response.error = UnserviceableError.new(response['Message'])
        return rate_response
      end

      if response['TotalCharge'].blank?
        rate_response.error = ResponseError.new('Cost is blank')
        return rate_response
      end

      estimate_reference = response['QuoteNum']
      expires_at = ::Time.iso8601(response['QuoteExpiryDate'])

      transit_days = (
        ::Time.iso8601(response['EarliestDeliveryDate']).to_date -
        ::Time.iso8601(response['PickupDate']).to_date
      ).to_i

      prices = []

      %w[AccessorialCharge FuelCharge HighCostCharge MinCharge].each do |charge_line_key|
        charge_line = response[charge_line_key]
        next unless charge_line

        cents = (charge_line.to_f * 100).to_i
        prices << Price.new(blame: :api, cents:, description: charge_line_key)
      end

      rate = Rate.new(
        carrier: self,
        carrier_name: self.class.name,
        currency: 'USD',
        estimate_reference:,
        expires_at:,
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
  end
end
