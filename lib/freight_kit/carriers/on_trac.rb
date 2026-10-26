module FreightKit
  module Carriers
    class OnTrac < FreightKit::Carrier
      class << self
        def find_rates_with_declared_value? = true
        def id = 'b1ba6e79-b7b3-41ae-a853-78bb75b421be'

        # Not really mapped but can be quoted
        def mappable_accessorials = { residential_delivery: true }

        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(150, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(6, :feet)
        def name = 'OnTrac'
        def overlength_fees_require_tariff? = false
        def pickup_number_is_tracking_number? = true
        def required_credential_types = %i[api_key]
        def requirements = %i[credentials]
        def scac = 'OTCL'
        def services = %i[standard guaranteed_delivery guaranteed_delivery_am guaranteed_delivery_pm]

        def unquotable_accessorials
          %i[
            airport_delivery
            airport_pickup
            amusement_park_delivery
            amusement_park_pickup
            appointment_delivery
            appointment_pickup
            athletic_facility_delivery
            athletic_facility_pickup
            brewery_delivery
            brewery_pickup
            cemetery_delivery
            cemetery_pickup
            church_delivery
            church_pickup
            construction_delivery
            construction_pickup
            convention_delivery
            convention_pickup
            customs_brokerage
            dock_dropoff
            dock_pickup
            driver_assist
            early_morning_delivery
            early_morning_pickup
            fair_delivery
            fair_pickup
            farm_delivery
            farm_pickup
            fitness_center_delivery
            fitness_center_pickup
            flatbed_delivery
            flatbed_pickup
            golf_course_delivery
            golf_course_pickup
            government_delivery
            government_pickup
            grocery_store_delivery
            grocery_store_pickup
            grocery_warehouse_delivery
            grocery_warehouse_pickup
            hospital_delivery
            hospital_pickup
            hotel_delivery
            hotel_pickup
            inside_delivery
            inside_pickup
            inspection_site_delivery
            inspection_site_pickup
            jobsite_delivery
            jobsite_pickup
            liftgate_delivery
            liftgate_pickup
            mall_delivery
            mall_pickup
            marina_delivery
            marina_pickup
            military_site_delivery
            military_site_pickup
            mine_site_delivery
            mine_site_pickup
            motel_delivery
            motel_pickup
            nursing_home_delivery
            nursing_home_pickup
            park_delivery
            park_pickup
            prison_delivery
            prison_pickup
            ranch_delivery
            ranch_pickup
            reservation_delivery
            reservation_pickup
            residential_pickup
            resort_delivery
            resort_pickup
            restaurant_delivery
            restaurant_pickup
            school_delivery
            school_pickup
            steel_mill_delivery
            steel_mill_pickup
            storage_facility_delivery
            storage_facility_pickup
            university_delivery
            university_pickup
            utility_site_delivery
            utility_site_pickup
            winery_delivery
            winery_pickup
          ]
        end

        def unserviceable_accessorials
          %i[afterhours_delivery afterhours_pickup guaranteed_delivery guaranteed_delivery_am guaranteed_delivery_pm]
        end

        def website_url = 'https://www.ontrac.com'
      end

      API = {
        domain: 'www.shipontrac.net',
        endpoints: {
          production: {
            pickups: '/OnTracWebServices/OnTracServices.svc/V4/' \
                                '%ACCOUNT_NUMBER%/pickups',
            rates: '/OnTracWebServices/OnTracServices.svc/V4/%ACCOUNT_NUMBER%/rates',
            shipments: '/OnTracWebServices/OnTracServices.svc/V4/' \
                                   '%ACCOUNT_NUMBER%/shipments'
          },
          test: {
            pickups: '/OnTracTestWebServices/OnTracServices.svc/V4/%ACCOUNT_NUMBER%/pickups',
            rates: '/OnTracTestWebServices/OnTracServices.svc/V4/%ACCOUNT_NUMBER%/rates',
            shipments: '/OnTracTestWebServices/OnTracServices.svc/V4/' \
                                              '%ACCOUNT_NUMBER%/shipments'
          }
        },
        methods: { pickups: :post, rates: :get, shipments: :post }
      }.freeze
      XML_HEADERS = { Accept: 'application/xml', charset: 'utf-8', 'Content-Type': 'application/xml' }.freeze

      # Documents

      # Pickups

      def create_pickup(
        delivery_from:,
        delivery_to:,
        dispatcher:,
        pickup_from:,
        pickup_to:,
        scac:,
        service:,
        shipment:
      )
        request = build_shipment_request(
          delivery_from:,
          delivery_to:,
          dispatcher:,
          pickup_from:,
          pickup_to:,
          scac:,
          service:,
          shipment:
        )

        labels = parse_shipment_response(commit(request))

        request = build_pickup_request(
          delivery_from:,
          delivery_to:,
          dispatcher:,
          pickup_from:,
          pickup_to:,
          scac:,
          service:,
          shipment:
        )

        parse_pickup_response(response: commit(request), labels:)
      end

      def find_rates(shipment:)
        begin
          validate_packages(shipment.packages)
        rescue UnserviceableError => e
          return RateResponse.new(error: e)
        end

        request = build_rate_request(shipment:)
        parse_rate_response(shipment:, response: commit(request))
      end

      # Tracking

      protected

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
        dispatcher_phone = dispatcher.phone.sub('+1', '').delete('^0-9')

        raise UnserviceableError, 'Palletized freight unsupported' unless shipment.loose?

        request_body = {
          Address: shipment.origin.address1,
          City: shipment.origin.city,
          CloseAt: pickup_to.strftime('%H:%M:00'),
          Contact: shipment.origin.contact.name || 'Shipping',
          Date: pickup_from.to_date,
          DelZip: shipment.destination.postal_code,
          Instructions: '',
          Name: shipment.origin.contact.company_name,
          Phone: dispatcher_phone,
          ReadyAt: pickup_from.strftime('%H:%M:00'),
          State: shipment.origin.province,
          Zip: shipment.origin.postal_code
        }.freeze

        request = {
          headers: XML_HEADERS,
          method: API.dig(:methods, :pickups),
          url: build_url(:pickups),
          body: request_body.to_xml(root: 'OnTracPickupRequest', skip_types: true)
        }

        save_request(request)
        request
      end

      def build_rate_request(shipment:)
        serviceable_accessorials?(shipment.accessorials)
        serviceable_states?([shipment.origin.province, shipment.destination.province])

        # API supports non-loose items (see below) but per OnTrac it shouldn't be quoted. We'll raise an error here but
        # leave the support baked-in below anyway.
        raise FreightKit::UnserviceableError, 'Palletized freight unsupported' unless shipment.loose?

        dim_weights_too_heavy = shipment.packages.map(&:dim_weight).select { |w| w > self.class.maximum_weight.value }

        if dim_weights_too_heavy.any?
          message = <<~MESSAGE.squish
            Dimensional weight(s) of #{dim_weights_too_heavy.map(&:round).join('lbs, ')} lbs more than maximum of
            #{self.class.maximum_weight.value.round} lbs
          MESSAGE
          raise FreightKit::UnserviceableError, message
        end

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

            parts = []

            parts << "ID#{i}"
            parts << shipment.origin.postal_code
            parts << shipment.destination.postal_code
            parts << shipment.accessorials.include?(:residential_delivery).to_s
            parts << '0'
            parts << 'false' # Staurday delivery
            parts << declared_value
            parts << package.pounds(:each).ceil
            parts << "#{package.inches(:length).ceil}X#{package.inches(:width).ceil}X#{package.inches(:height).ceil}"
            parts << 'C'
            parts << '0' # not a letter
            parts << '0' # always 0 per documentation

            package_param_parts << parts.join(';')
          end
        end

        params << package_param_parts.join(',')

        build_request(:rates, { params: })
      end

      def build_request(action, options = {})
        request = { url: build_url(action, options), headers: XML_HEADERS, method: API.dig(:methods, action) }

        save_request(request)
        request
      end

      def build_shipment_request(
        delivery_from:,
        delivery_to:,
        dispatcher:,
        pickup_from:,
        pickup_to:,
        scac:,
        service:,
        shipment:
      )
        dispatcher_phone = dispatcher.phone.sub('+1', '').delete('^0-9')
        receiver_phone = shipment.destination.contact.phone.sub('+1', '').delete('^0-9')

        declared_value = if shipment.declared_value_cents.blank?
                           '0'
                         else
                           format('%.2f', (shipment.declared_value_cents.to_f / 100).ceil)
                         end

        raise UnserviceableError, 'Palletized freight unsupported' unless shipment.loose?

        base_api_shipment = {
          consignee: {
            Name: shipment.destination.contact.company_name,
            Addr1: shipment.destination.address1,
            Addr2: '',
            Addr3: '',
            City: shipment.destination.city,
            Contact: shipment.destination.contact.name || 'Shipping',
            Phone: receiver_phone || '',
            State: shipment.destination.province,
            Zip: shipment.destination.postal_code.to_s
          },
          shipper: {
            Name: shipment.origin.contact.company_name,
            Addr1: shipment.origin.address1,
            City: shipment.origin.city,
            State: shipment.origin.province,
            Zip: shipment.origin.postal_code,
            Contact: shipment.origin.contact.name || 'Shipping',
            Phone: dispatcher_phone
          },
          BillTo: '0',
          CargoType: '0',
          COD: '0',
          CODType: 'NONE',
          Declared: declared_value,
          DelEmail: dispatcher.email,
          Instructions: '',
          LabelType: '1', # PDF label
          Reference: shipment.order_number,
          Reference2: shipment.po_number,
          Reference3: '',
          Residential: shipment.accessorials.include?(:residential_delivery) ? 'true' : 'false',
          SaturdayDel: 'false',
          Service: 'C',
          ShipDate: pickup_from.to_date.to_s,
          ShipEmail: dispatcher.email,
          SignatureRequired: 'true',
          Tracking: ''
        }.freeze

        api_shipments = []

        shipment.packages.each do |package|
          package.quantity.times do
            api_shipments << base_api_shipment.merge(
              {
                DIM: {
                  Length: package.length(:inches).ceil,
                  Width: package.width(:inches).ceil,
                  Height: package.height(:inches).ceil
                },
                UID: SecureRandom.uuid,
                Weight: package.pounds(:each).ceil
              }
            )
          end
        end

        request = {
          headers: XML_HEADERS,
          method: API.dig(:methods, :shipments),
          url: build_url(:shipments),
          body: { Shipments: api_shipments }.to_xml(root: 'OnTracShipmentRequest', skip_types: true)
        }

        save_request(request)
        request
      end

      def build_url(action, options = {})
        api_credentials = fetch_credential(:api_key)

        env = @test_mode ? :test : :production

        url = "https://#{API[:domain]}#{API.dig(:endpoints, env, action)}"
        url = url.gsub('%ACCOUNT_NUMBER%', api_credentials.account)

        url += "?pw=#{api_credentials.api_key}"
        url << "&#{options[:params]}" if options[:params].present?

        url
      end

      def commit(request)
        body = request[:body]
        headers = request[:headers]
        method = request[:method]
        url = request[:url]

        response = case method
                   when :post
                     HTTPClient.post(url, headers:, body:)
                   else
                     HTTPClient.get(url, headers:)
                   end

        response.parsed_response if response&.parsed_response
      end

      def parse_pickup_response(response:, labels:)
        pickup_response = PickupResponse.new(request: last_request, response:)

        if response.blank?
          pickup_response.error = FreightKit::ResponseError.new('API Error: Blank response')
          return pickup_response
        end

        error = response.dig('OnTracPickupResponse', 'Error')

        if error.present?
          pickup_response.error = FreightKit::ResponseError.new(error.capitalize)
          return pickup_response
        end

        pickup_number = response.dig('OnTracPickupResponse', 'Tracking')

        if pickup_number.blank?
          pickup_response.error = FreightKit::ResponseError.new('Blank pickup number')
          return pickup_response
        end

        pickup_response.pickup_number = pickup_number
        pickup_response
      end

      def parse_rate_response(shipment:, response:)
        rate_response = RateResponse.new(request: last_request, response:)

        if response.blank?
          rate_response.error = ResponseError.new('Blank response')
          return rate_response
        end

        error = response.dig('OnTracRateResponse', 'Shipments', 'Shipment', 'Error') ||
                response.dig('OnTracRateResponse', 'Shipments', 'Error') ||
                response.dig('OnTracRateResponse', 'Error')

        if error.blank? && response.dig('OnTracRateResponse', 'Shipments', 'Shipment').is_a?(Hash)
          error = response.dig('OnTracRateResponse', 'Shipments', 'Shipment', 'Rates', 'Rate', 'Error')
        end

        if error.present?
          case error.downcase
          when ->(value) { value.include?('not serviced') }
            rate_response.error = UnserviceableError.new(error)
            return rate_response
          when ->(value) { value.include?('invalid username') }
            rate_response.error = InvalidCredentialsError.new(error)
            return rate_response
          when ->(value) { value.include?('no valid service') }
            rate_response.error = UnserviceableError.new(error)
            return rate_response
          end

          rate_response.error = ResponseError.new(error)
          return rate_response
        end

        prices = []
        transit_days = nil

        api_shipments = response.dig('OnTracRateResponse', 'Shipments', 'Shipment')
        api_shipments = [api_shipments] unless api_shipments.is_a?(Array)

        if api_shipments.any? { |api_shipment| api_shipment['Error']&.downcase&.include?('not serviced') }
          rate_response.error = UnserviceableError.new
          return rate_response
        end

        api_shipments.each do |api_shipment|
          api_rate = api_shipment.dig('Rates', 'Rate')
          api_transit_days = api_rate['TransitDays'].to_i

          transit_days = api_transit_days if transit_days.blank? || transit_days < api_transit_days

          cents = (api_rate['ServiceCharge'].to_f * 100).to_i
          prices << Price.new(blame: :api, cents:, description: 'Service charge')

          cents = (api_rate['FuelCharge'].to_f * 100).to_i
          prices << Price.new(blame: :api, cents:, description: 'Fuel charge')
        end

        rate = Rate.new(
          carrier_name: name,
          carrier: self,
          currency: 'USD',
          prices:,
          scac:,
          service_name: :standard,
          shipment:,
          transit_days:,
          with_excessive_length_fees: rates_with_excessive_length_fees?
        )

        rate_response.rates = [rate]
        rate_response
      end

      def parse_shipment_response(response)
        raise FreightKit::ResponseError, 'API Error: Blank response' if response.blank?

        error = response.dig('OnTracShipmentResponse', 'Shipments', 'Error')

        if error.blank? && response.dig('OnTracShipmentResponse', 'Shipments', 'Shipment').is_a?(Hash)
          error = response.dig('OnTracShipmentResponse', 'Shipments', 'Shipment', 'Error')
        end

        if error.present?
          error = error.capitalize

          raise FreightKit::InvalidCredentialsError, error if error.downcase.include?('invalid username')

          raise FreightKit::UnserviceableError, error if error.downcase.include?('no valid service')

          raise FreightKit::UnserviceableError, error if error.downcase.include?('not serviced')

          raise FreightKit::ResponseError, "API Error: #{error}"
        end

        api_shipments = response.dig('OnTracShipmentResponse', 'Shipments', 'Shipment')
        api_shipments = [api_shipments] unless api_shipments.is_a?(Array)

        base64_labels = api_shipments&.map { |s| s['Label'] }
        raise FreightKit::ResponseError, 'API Error: Blank label' if base64_labels.blank?

        base64_labels.map { |base64_label| Label.new(data: base64_label) }
      end

      def serviceable_states?(states)
        valid_states = ['AZ', 'CA', 'CO', 'ID', 'NV', 'OR', 'UT', 'WA']

        invalid_states = []
        states.each do |state|
          invalid_states << state if valid_states.exclude?(state)
        end

        return true if invalid_states.blank?

        raise FreightKit::UnserviceableError, "No service to #{invalid_states.join(', ')}"
      end

      # Tracking
    end
  end
end
