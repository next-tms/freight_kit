module FreightKit
  module Carriers
    class CrossCountryFreightSolutions < FreightKit::Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Bismarck',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'bc2db4c6-b4c8-4082-adfc-4a3e764510a7',
              postal_code: '58502',
              region_abbreviation: 'ND',
              street: 'PO Box 4030'
            )
          ]
        end

        def contacts
          [Contact.new(department: 'Main', id: '2336a4d3-4f04-4eab-9e38-d0afb74dce62', phone: '+17012228498')]
        end

        def headquarters
          Address.new(
            city: 'Bismarck',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'f78d1f2e-1299-405b-a0a2-45c99b4d7a14',
            postal_code: '58501',
            region_abbreviation: 'ND',
            street: '1841 Hancock Drive'
          )
        end

        def id = '08c02bcf-11fb-40a7-950a-58e6503f540f'
        def legal_name = 'CrossCountry Freight Solutions Inc'

        # Per carrier at 2022-12-16T02:31:00Z
        def mappable_accessorials
          {
            afterhours_delivery: 'AFTERHRS',
            afterhours_pickup: 'AFTERHRS',
            airport_delivery: 'AIRPORT PD',
            airport_pickup: 'AIRPORT PD',
            amusement_park_delivery: 'LIMITEDACC',
            amusement_park_pickup: 'LIMITEDACC',
            appointment_delivery: 'APPT_NOTIF',
            appointment_pickup: 'APPT_NOTIF',
            athletic_facility_delivery: 'LIMITEDACC',
            athletic_facility_pickup: 'LIMITEDACC',
            brewery_delivery: 'LIMITEDACC',
            brewery_pickup: 'LIMITEDACC',
            cemetery_delivery: 'LIMITEDACC',
            cemetery_pickup: 'LIMITEDACC',
            church_delivery: 'LIMITEDACC',
            church_pickup: 'LIMITEDACC',
            construction_delivery: 'LIMITEDACC',
            construction_pickup: 'LIMITEDACC',
            convention_delivery: 'LIMITEDACC',
            convention_pickup: 'LIMITEDACC',
            corrected_bol: 'BOL_CORR',
            driver_assist: 'EXTRA LBR',
            early_morning_delivery: 'AFTERHRS',
            fair_delivery: 'LIMITEDACC',
            fair_pickup: 'LIMITEDACC',
            farm_delivery: 'LIMITEDACC',
            farm_pickup: 'LIMITEDACC',
            fitness_center_delivery: 'LIMITEDACC',
            fitness_center_pickup: 'LIMITEDACC',
            golf_course_delivery: 'LIMITEDACC',
            golf_course_pickup: 'LIMITEDACC',
            government_delivery: 'LIMITEDACC',
            government_pickup: 'LIMITEDACC',
            grocery_store_delivery: 'LIMITEDACC',
            grocery_store_pickup: 'LIMITEDACC',
            grocery_warehouse_delivery: 'FOODWREHSE',
            grocery_warehouse_pickup: 'FOODWREHSE',
            hospital_delivery: 'LIMITEDACC',
            hospital_pickup: 'LIMITEDACC',
            hotel_delivery: 'LIMITEDACC',
            hotel_pickup: 'LIMITEDACC',
            inside_delivery: 'INSIDE',
            inside_pickup: 'INSIDE',
            inspection_site_delivery: 'LIMITEDACC',
            inspection_site_pickup: 'LIMITEDACC',
            jobsite_delivery: 'LIMITEDACC',
            jobsite_pickup: 'LIMITEDACC',
            liftgate_delivery: 'LIFTGT',
            liftgate_pickup: 'LIFTGT',
            mall_delivery: 'MALL',
            mall_pickup: 'MALL',
            marina_delivery: 'LIMITEDACC',
            marina_pickup: 'LIMITEDACC',
            military_site_delivery: 'LIMITEDACC',
            military_site_pickup: 'LIMITEDACC',
            mine_site_pickup: 'LIMITEDACC',
            motel_delivery: 'LIMITEDACC',
            motel_pickup: 'LIMITEDACC',
            nursing_home_delivery: 'LIMITEDACC',
            nursing_home_pickup: 'LIMITEDACC',
            park_delivery: 'LIMITEDACC',
            park_pickup: 'LIMITEDACC',
            prison_delivery: 'LIMITEDACC',
            prison_pickup: 'LIMITEDACC',
            ranch_delivery: 'LIMITEDACC',
            ranch_pickup: 'LIMITEDACC',
            reservation_delivery: 'APPT_NOTIF',
            reservation_pickup: 'APPT_NOTIF',
            residential_delivery: 'RESIDENT',
            residential_pickup: 'RESIDENT',
            resort_delivery: 'LIMITEDACC',
            resort_pickup: 'LIMITEDACC',
            restaurant_delivery: 'LIMITEDACC',
            restaurant_pickup: 'LIMITEDACC',
            school_delivery: 'LIMITEDACC',
            school_pickup: 'LIMITEDACC',
            steel_mill_delivery: 'LIMITEDACC',
            steel_mill_pickup: 'LIMITEDACC',
            storage_facility_delivery: 'LIMITEDACC',
            storage_facility_pickup: 'LIMITEDACC',
            university_delivery: 'LIMITEDACC',
            university_pickup: 'LIMITEDACC',
            utility_site_delivery: 'LIMITEDACC',
            utility_site_pickup: 'LIMITEDACC',
            winery_delivery: 'LIMITEDACC',
            winery_pickup: 'LIMITEDACC'
          }
        end

        def minimum_length_for_overlength_fees = Measured::Length.new(6, :feet)
        def name = 'CrossCountry Freight Solutions'
        def overlength_fees_require_tariff? = false
        def required_credential_types = %i[api_key api_proxy]
        def requirements = %i[credentials]
        def scac = 'CCYQ'
        def unquotable_accessorials = %i[athletic_facility_delivery dock_dropoff dock_pickup]

        def unserviceable_accessorials
          %i[
            customs_brokerage
            flatbed_delivery
            flatbed_pickup
            guaranteed_delivery
            guaranteed_delivery_am
            guaranteed_delivery_pm
          ]
        end

        def us_dot_number = 313_378
        def us_mc_number = 209_657
        def website_url = 'https://www.ccfs.com'
      end

      include FreightKit::Rateable
      include FreightKit::Trackable
      include FreightKit::Documentable
      include FreightKit::Pickupable

      API = {
        domain: 'ccfs.com/api/public',
        endpoints: { bol: '/Image', pod: '/Image', rates: '/Quote', track: '/Track', pickup: '/Pickup' },
        methods: { bol: :get, pod: :get, rates: :post, track: :get, pickup: :post }
      }.freeze
      JSON_HEADERS = { Accept: 'application/json', charset: 'utf-8', 'Content-Type' => 'application/json' }.freeze

      protected

      def build_accessorials(shipment:)
        accessorials = []
        serviceable_accessorials?(shipment.accessorials)

        accessorials << { Code: 'HAZMAT', Factor: 1 } if shipment.hazmat?

        shipment.packages.each do |package|
          longest_dimension = [package.width(:inches), package.length(:inches)].max.ceil

          next if longest_dimension < 96

          package.quantity.times do
            accessorials << { Code: 'EXLEN', Factor: longest_dimension }
          end
        end

        shipment.accessorials.map do |accessorial|
          next if unquotable_accessorials.include?(accessorial)

          accessorials << { Code: mappable_accessorials[accessorial.to_sym], Factor: 1 }
        end

        accessorials
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
        dispatcher_phone = dispatcher.phone.delete('^0-9')
        receiver = shipment.destination.contact
        receiver_phone = receiver.phone.delete('^0-9')

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
              Name: receiver.company_name || receiver.name,
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

      def build_rate_request(shipment:)
        build_request(
          :rates,
          body: {
            Orig: shipment.origin.postal_code,
            Dest: shipment.destination.postal_code,
            Accessorials: build_accessorials(shipment:),
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

      def build_request(action, body: {}, query: {})
        api_key = fetch_credential(:api_key).api_key
        proxy_url = fetch_credential(:api_proxy).proxy_url

        request = {
          url: build_url(action),
          headers: { APIKEY: api_key },
          method: API.dig(:methods, action),
          body:,
          query:,
          proxy_url:
        }.compact

        save_request(request)
        request
      end

      def build_tracking_request(tracking_number) = build_request(:track, query: { ReferenceNum: tracking_number })
      def build_url(action) = "https://#{API[:domain]}#{API.dig(:endpoints, action)}"

      def commit(_action, request)
        response = HTTPClient.request(
          request[:method],
          request[:url],
          headers: request[:headers].merge(JSON_HEADERS),
          body: request[:body],
          query: request[:query],
          proxy: request[:proxy_url]
        )

        unless response.code == 200
          message = begin
            JSON.parse(response.body)['Message'] || "HTTP #{response.code}"
          rescue JSON::ParserError
            "HTTP #{response.code}"
          end

          raise FreightKit::InvalidCredentialsError, message if message == 'API key is inactive'

          raise FreightKit::ResponseError, message
        end

        JSON.parse(response.body)
      end

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

        unless response
          document_response.error = DocumentNotFoundError.new
          return document_response
        end

        document = response['Images']&.find { |image| image['DocumentType'] == type.upcase }

        unless document
          document_response.error = DocumentNotFoundError.new
          return document_response
        end

        decoded_pdf_data = Base64.decode64(document['Content'])
        document_response.assign_attributes(content_type: 'application/pdf', data: decoded_pdf_data)

        document_response
      end

      def parse_pickup_response(response)
        pickup_response = PickupResponse.new(request: last_request, response:)
        pickup_number = response['FreightBillNum']

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

        ['AccessorialCharge', 'FuelCharge', 'HighCostCharge', 'MinCharge'].each do |charge_line_key|
          charge_line = response[charge_line_key]
          next unless charge_line

          cents = (charge_line.to_f * 100).to_i
          prices << Price.new(blame: :api, cents:, description: charge_line_key)
        end

        rate = Rate.new(
          carrier: self,
          carrier_name: name,
          currency: 'USD',
          estimate_reference:,
          expires_at:,
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

      def parse_tracking_response(response)
        TrackingResponse.new(carrier: self, request: last_request, response:)

        # TODO
      end
    end
  end
end
