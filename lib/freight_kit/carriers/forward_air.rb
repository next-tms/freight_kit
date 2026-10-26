module FreightKit
  module Carriers
    class ForwardAir < FreightKit::Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Knoxville',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'a73d400c-4ed9-4bfb-a9d9-6842cb3bde7d',
              postal_code: '37995',
              region_abbreviation: 'TN',
              street: 'Dept 888155'
            )
          ]
        end

        def find_rates_with_declared_value? = true
        def id = 'c69bfbcd-3a1f-4d2f-9dd6-c357ab9193de'
        def legal_name = 'Forward Air, LLC'
        def mappable_accessorials = DELIVERY_ACCESSORIALS.merge(PICKUP_ACCESSORIALS)
        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(6, :feet)
        def name = 'Forward Air'
        def overlength_fees_require_tariff? = false
        def pickup_number_is_tracking_number? = true
        def rates_with_excessive_length_fees? = false
        def required_credential_types = %i[api]
        def requirements = %i[credentials]
        def scac = 'FWDA'
        def services = %i[standard_ltl]

        def unquotable_accessorials
          %i[
            athletic_facility_delivery
            athletic_facility_pickup
            cemetery_delivery
            cemetery_pickup
            church_delivery
            church_pickup
            construction_delivery
            construction_pickup
            dock_dropoff
            dock_pickup
            driver_assist
            farm_delivery
            farm_pickup
            fitness_center_delivery
            fitness_center_pickup
            golf_course_delivery
            golf_course_pickup
            government_delivery
            government_pickup
            grocery_store_delivery
            grocery_store_pickup
            jobsite_delivery
            jobsite_pickup
            marina_delivery
            marina_pickup
            mine_site_delivery
            mine_site_pickup
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
            restaurant_delivery
            restaurant_pickup
            school_pickup
            steel_mill_delivery
            steel_mill_pickup
            storage_facility_delivery
            storage_facility_pickup
            university_pickup
            utility_site_delivery
            utility_site_pickup
          ]
        end

        def unserviceable_accessorials
          %i[
            brewery_delivery
            brewery_pickup
            customs_brokerage
            flatbed_delivery
            flatbed_pickup
            grocery_warehouse_delivery
            grocery_warehouse_pickup
            guaranteed_delivery
            guaranteed_delivery_am
            guaranteed_delivery_pm
            inspection_site_delivery
            inspection_site_pickup
            winery_delivery
            winery_pickup
          ]
        end

        def us_dot_number = 2_215_557
        def us_mc_number = 249_708
      end

      include FreightKit::Rateable
      include FreightKit::Trackable
      include FreightKit::Pickupable

      API = {
        domains: { production: 'api.forwardair.com', test: 'test-api.forwardair.com' },
        endpoints: {
          documents: '/ltlservices/v2/rest/waybills/%TRACKING_NUMBER%/documents',
          document: '/ltlservices/v2/rest/waybills/%TRACKING_NUMBER%/documents/download' \
                                     '?docId=%DOC_ID%',
          locations: '/ltlservices/v2/rest/ltlinfo/liststations',
          pickup: '/ltlservices/v2/rest/waybills/book/json',
          rates: '/ltlservices/v2/rest/waybills/quote/json',
          track: '/ltlservices/v2/rest/waybills/%TRACKING_NUMBER%/statuses'
        },
        methods: { locations: :get, pickup: :post, rates: :post, track: :get },
        use_ssl: true
      }.freeze
      DELIVERY_ACCESSORIALS = {
        afterhours_delivery: 'XPD',
        airport_delivery: 'ALD',
        amusement_park_delivery: 'CCD',
        appointment_delivery: 'ADE',
        convention_delivery: 'CCD',
        early_morning_delivery: 'XPD',
        fair_delivery: 'CCD',
        hospital_delivery: 'HDC',
        hotel_delivery: 'HOD',
        inside_delivery: 'IDE',
        liftgate_delivery: 'LGD',
        mall_delivery: 'MDC',
        military_site_delivery: 'MBD',
        motel_delivery: 'HOD',
        residential_delivery: 'RDE',
        resort_delivery: 'HOD',
        school_delivery: 'UND',
        university_delivery: 'UND'
      }.freeze
      EVENTS = {
        types: {
          arrived_at_terminal: 'ARR',
          delivered: 'DLV',
          delivery_appointment_scheduled: 'DPL',
          departed: 'DEP',
          located: 'ARRD',
          out_for_delivery: 'OUTDV',
          picked_up: 'PUP',
          pickup_driver_assigned: 'DPUP'
        }
      }.freeze
      JSON_HEADERS = { Accept: 'application/json', charset: 'utf-8', 'Content-Type' => 'application/json' }.freeze
      PICKUP_ACCESSORIALS = {
        afterhours_pickup: 'XPU',
        airport_pickup: 'ALP',
        amusement_park_pickup: 'CCP',
        appointment_pickup: 'APP',
        convention_pickup: 'CCP',
        early_morning_pickup: 'XPU',
        fair_pickup: 'CCP',
        hospital_pickup: 'HPC',
        hotel_pickup: 'HOT',
        inside_pickup: 'IPU',
        liftgate_pickup: 'LGP',
        mall_pickup: 'MPC',
        military_site_pickup: 'MBP',
        motel_pickup: 'HOT',
        residential_pickup: 'RPU',
        resort_pickup: 'HOP'
      }.freeze

      # Documents

      def find_locations(country)
        raise ArgumentError, 'country must be a ActiveUtils::Country' unless country.is_a?(ActiveUtils::Country)

        request = build_locations_request
        parse_locations_response(country:, response: commit(request))
      end

      def find_rates(shipment:)
        if shipment.packages.map { |package| package.height(:in) }.any?(&:blank?) ||
           shipment.packages.map { |package| package.length(:in) }.any?(&:blank?) ||
           shipment.packages.map { |package| package.width(:in) }.any?(&:blank?)

          raise UnserviceableError, 'Dimensions required for quoting'
        end

        packages = shipment.packages.select { |package| package.height(:in) > 89 }
        if packages.any?
          message = <<~MESSAGE.squish
            #{'Height'.pluralize(packages)}
            #{packages.map { |package| "#{package.height(:in)} inches" }.join(', ')}
            greater than maximum allowed of 89 inches.
          MESSAGE
          raise UnserviceableError, message
        end

        packages = shipment.packages.select { |package| package.length(:in) > 240 }
        if packages.any?
          message = <<~MESSAGE.squish
            #{'Length'.pluralize(packages)}
            #{packages.map { |package| "#{package.length(:in)} inches" }.join(', ')}
            greater than maximum allowed of 240 inches.
          MESSAGE
          raise UnserviceableError, message
        end

        packages = shipment.packages.select { |package| package.width(:in) > 82 }
        if packages.any?
          message = <<~MESSAGE.squish
            #{'Width'.pluralize(packages)}
            #{packages.map { |package| "#{package.width(:in)} inches" }.join(', ')}
            greater than maximum allowed of 82 inches.
          MESSAGE
          raise UnserviceableError, message
        end

        super
      end

      def pod(tracking_number)
        # Retrieve list of available documents first
        begin
          documents = commit(build_documents_request(tracking_number))
        rescue FreightKit::ResponseError => e
          return DocumentResponse.new(error: FreightKit::DocumentNotFoundError) if e.message.downcase.include?('no airbills found')

          return DocumentResponse.new(error: e)
        end

        begin
          doc_id = get_doc_id(documents:, tracking_number:, type: :pod)
        rescue StandardError => e
          return DocumentResponse.new(error: e)
        end

        request = build_document_request(doc_id:, tracking_number:)
        response = commit(request)

        parse_document_response(:pod, tracking_number, response)
      end

      def scanned_bol(tracking_number, _options = {})
        # Retrieve list of available documents first
        begin
          documents = commit(build_documents_request(tracking_number))
        rescue FreightKit::ResponseError => e
          return DocumentResponse.new(error: FreightKit::DocumentNotFoundError) if e.message.downcase.include?('no airbills found')

          return DocumentResponse.new(error: e)
        end

        begin
          doc_id = get_doc_id(documents:, tracking_number:, type: :bol)
        rescue StandardError => e
          return DocumentResponse.new(e:)
        end

        request = build_document_request(doc_id:, tracking_number:)
        response = commit(request)

        parse_document_response(:bol, tracking_number, response)
      end

      protected

      def base_url = "https://#{API.dig(:domains, :production)}"

      def build_accessorials(accessorials)
        delivery_accessorials = []
        pickup_accessorials = []

        if accessorials.present?
          serviceable_accessorials?(accessorials)

          accessorials.excluding(unserviceable_accessorials).each do |a|
            delivery_accessorials << DELIVERY_ACCESSORIALS[a] if DELIVERY_ACCESSORIALS.include?(a)
            pickup_accessorials << PICKUP_ACCESSORIALS[a] if PICKUP_ACCESSORIALS.include?(a)
          end
        end

        if delivery_accessorials.present? && delivery_accessorials.include?('RDE')
          # Remove duplicate delivery appointment accessorial when residential delivery (included with RDE)
          delivery_accessorials -= ['ADE']
        end

        if pickup_accessorials.present? && pickup_accessorials.include?('RPU')
          # Remove duplicate pickup appointment accessorial when residential pickup (included with RPU)
          pickup_accessorials -= ['APP']
        end

        # API doesn't like empty arrays
        delivery_accessorials = nil if delivery_accessorials.blank?
        pickup_accessorials = nil if pickup_accessorials.blank?

        [pickup_accessorials&.uniq, delivery_accessorials&.uniq]
      end

      def build_dimensions(packages)
        packages.map do |package|
          {
            height: package.height(:in).ceil,
            length: package.length(:in).ceil,
            pieces: package.quantity,
            width: package.width(:in).ceil
          }
        end
      end

      def build_document_request(doc_id:, tracking_number:)
        request = {
          url: build_url(:document, doc_id:, tracking_number:),
          headers: build_headers,
          method: API.dig(:methods, :documents)
        }

        save_request(request)
        request
      end

      def build_documents_request(tracking_number)
        request = {
          url: build_url(:documents, tracking_number:),
          headers: build_headers,
          method: API.dig(:methods, :documents)
        }

        save_request(request)
        request
      end

      def build_freight_details(packages)
        packages.map do |package|
          {
            description: package.description || 'Freight',
            freightClass: package.freight_class.to_s,
            pieces: package.quantity.to_s,
            weightType: 'L',
            weight: package.pounds(:total).ceil.to_s
          }
        end
      end

      def build_headers
        api_credentials = fetch_credential(:api)

        JSON_HEADERS.merge(
          {
            billToAccountNumber: api_credentials.account,
            customerId: api_credentials.username.upcase,
            password: api_credentials.password,
            user: api_credentials.username
          }
        )
      end

      def build_locations_request
        request = { url: build_url(:locations), headers: build_headers, method: API.dig(:methods, :locations) }

        save_request(request)
        request
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
        pickup_accessorials, delivery_accessorials = build_accessorials(shipment.accessorials)

        dispatcher_phone = dispatcher.phone.delete('^0-9')
        shipper_phone = shipment.origin.contact.phone.delete('^0-9')
        receiver_phone = shipment.destination.contact.phone.delete('^0-9')

        api_credentials = fetch_credential(:api)

        declared_value = if shipment.declared_value_cents.blank?
                           '0'
                         else
                           format('%.2f', (shipment.declared_value_cents.to_f / 100).ceil)
                         end

        delivery = {
          airportDelivery: delivery_accessorials&.include?('ALD') ? 'Y' : 'N',
          deliveryAccessorials: { deliveryAccessorial: delivery_accessorials }
        }
        description = shipment.packages.map(&:description).reject(&:blank?).uniq.join(', ')

        request = {
          headers: build_headers,
          method: API.dig(:methods, :pickup),
          url: build_url(:pickup),
          body: {
            testmode: 'N',
            consignee: {
              consigneeAddress1: shipment.destination.address1,
              consigneeAddress2: '',
              consigneeCity: shipment.destination.city,
              consigneeCloseTime: delivery_to.strftime('%H:%M:00'),
              consigneeContactEmail: '',
              consigneeContactName: shipment.destination.contact.name || 'Receiving',
              consigneeContactPhone: receiver_phone || '',
              consigneeCountry: shipment.destination.country.code(:alpha2).value,
              consigneeLocationName: shipment.destination.contact.name,
              consigneeOpenTime: delivery_from.strftime('%H:%M:00'),
              consigneeState: shipment.destination.province,
              consigneeZipCode: shipment.destination.postal_code.to_s
            },
            shipper: {
              shipperAddress1: shipment.origin.address1,
              shipperAddress2: '',
              shipperCity: shipment.origin.city,
              shipperCloseTime: pickup_to.strftime('%H:%M:00'),
              shipperContactEmail: '',
              shipperContactName: shipment.origin.contact.name || 'Shipping',
              shipperContactPhone: shipper_phone || '',
              shipperCountry: shipment.origin.country.code(:alpha2).value,
              shipperLocationName: shipment.origin.contact.name,
              shipperOpenTime: pickup_from.strftime('%H:%M:00'),
              shipperState: shipment.origin.province,
              shipperZipCode: shipment.origin.postal_code.to_s
            },
            orderDetails: {
              airbillNumber: '00000000',
              billToCustomerNumber: api_credentials.account.to_s,
              customerReferenceNumber: shipment.po_number,
              declaredValue: declared_value,
              description:,
              destinationAirportCode: '',
              guaranteedService: 'N',
              hazmat: shipment.hazmat? ? 'Y' : 'N',
              inBondShipment: declared_value.to_f.positive? ? 'Y' : 'N',
              orderAction: 'CREATE',
              originAirportCode: '',
              shippingDate: pickup_from.strftime('%Y-%m-%d'),
              shipperCustomerNumber: api_credentials.account.to_s,
              specialInstructions: '',
              dimensions: {
                dimension: shipment.packages.map do |package|
                  {
                    height: package.inches(:height).ceil.to_s,
                    length: package.inches(:length).ceil.to_s,
                    width: package.inches(:width).ceil.to_s,
                    pieces: package.quantity.to_s
                  }
                end
              },
              freightDetails: { freightDetail: build_freight_details(shipment.packages) },
              delivery:,
              emergencyContact: { email: dispatcher.email, name: dispatcher.name, phone: dispatcher_phone },
              pickup: {
                airportPickup: pickup_accessorials&.include?('ALP') ? 'Y' : 'N',
                pickupAccessorials: { pickupAccessorial: pickup_accessorials },
                pickupReadyTime: pickup_from.strftime('%H:%M:00')
              },
              referenceNumbers: { referenceNumber: [shipment.order_number, shipment.po_number, ''] }
            }
          }.to_json
        }

        save_request(request)
        request
      end

      def build_rate_request(shipment:)
        api_credentials = fetch_credential(:api)

        freight_details = build_freight_details(shipment.packages)
        dimensions = build_dimensions(shipment.packages)
        declared_value = if shipment.declared_value_cents.blank?
                           '0'
                         else
                           format('%.2f', (shipment.declared_value_cents.to_f / 100).ceil)
                         end
        pickup_accessorials, delivery_accessorials = build_accessorials(shipment.accessorials)

        delivery = {
          airportDelivery: delivery_accessorials&.include?('ALD') ? 'Y' : 'N',
          deliveryAccessorials: { deliveryAccessorial: delivery_accessorials }
        }

        request = {
          url: build_url(:rates),
          headers: build_headers,
          method: API.dig(:methods, :rates),
          body: {
            billToCustomerNumber: api_credentials.account,
            origin: {
              originZipCode: shipment.origin.postal_code.to_s.upcase,
              pickup: {
                airportPickup: pickup_accessorials&.include?('ALP') ? 'Y' : 'N',
                pickupAccessorials: { pickupAccessorial: pickup_accessorials }
              }
            },
            destination: { destinationZipCode: shipment.destination.postal_code.to_s.upcase, delivery: },
            dimensions: { dimension: dimensions },
            freightDetails: { freightDetail: freight_details },
            hazmat: shipment.hazmat? ? 'Y' : 'N',
            inBondShipment: 'N',
            declaredValue: declared_value,
            shippingDate: Date.current.strftime('%Y-%m-%d')
          }.to_json
        }

        save_request(request)
        request
      end

      def build_request(action, options = {})
        headers = JSON_HEADERS
        headers = headers.merge(options[:headers]) if options[:headers].present?
        body = options[:body].to_json if options[:body].present?

        request = { url: build_url(action, options), headers:, method: API.dig(:methods, action), body: }

        save_request(request)
        request
      end

      def build_tracking_request(tracking_number)
        request = {
          url: build_url(:track, tracking_number:),
          headers: build_headers,
          method: API.dig(:methods, :track),
          body: { billToCustomerNumber: fetch_credential(:api).account, referenceNumber: tracking_number.to_s }.to_json
        }

        save_request(request)
        request
      end

      def build_url(action, options = {})
        url = "#{base_url}#{API.dig(:endpoints, action)}"
        url = url.gsub('%TRACKING_NUMBER%', options[:tracking_number]) if options[:tracking_number]
        url = url.gsub('%DOC_ID%', options[:doc_id]) if options[:doc_id]

        url
      end

      def charge_line_item_description(charge_line_item)
        description = charge_line_item['description'] || ''
        description = description.gsub('-', '')
        description = description.capitalize

        code = charge_line_item['code']&.upcase || ''
        description = "#{description} (#{code})" if code.present?
        description = description.gsub('Fsc', 'FSC') if description.include?('Fsc')

        description.squish
      end

      def commit(request)
        url = request[:url]
        headers = request[:headers]
        method = request[:method]
        body = request[:body]

        response = case method
                   when :post
                     HTTPClient.post(url, headers:, body:)
                   else
                     HTTPClient.get(url, headers:)
                   end

        if (200..299).exclude?(response.code)
          message = begin
            JSON.parse(response.body)['errorMessage'] || "HTTP #{response.code}"
          rescue JSON::ParserError
            "HTTP #{response.code}"
          end

          raise FreightKit::ResponseError, message
        end

        return response if response.content_type != 'application/json'

        json = JSON.parse(response.body)
        error = json.is_a?(Array) ? nil : json['errorMessage']

        return json if error.blank?

        raise FreightKit::InvalidCredentialsError, error if error.downcase.include?('not authorized')
        raise FreightKit::InvalidCredentialsError, error if error.downcase.include?('shipper client does not exist')
        raise FreightKit::ShipmentNotFoundError, error if error.downcase.include?('no history found')
        raise FreightKit::UnserviceableError, error if error.downcase.include?('not serviced')

        raise FreightKit::ResponseError, error
      end

      def get_doc_id(documents:, tracking_number:, type:)
        type = type.to_s.upcase
        link = nil

        documents.each do |document|
          next unless document['documentType'] == type

          link = document['link']
        end

        raise FreightKit::DocumentNotFoundError, "API Error: #{name}: Document not found" unless link

        query = URI.parse(link).query
        doc_id = URI.decode_www_form(query).assoc('docId')&.last

        raise FreightKit::DocumentNotFoundError, "API Error: #{name}: Document not found" unless doc_id

        doc_id
      end

      def parse_api_date_time(date_time, location)
        return if date_time.blank?

        local_date_time = ::Time.strptime(date_time, '%m/%d/%y %H:%M').to_fs(:db)
        ::FreightKit::DateTime.new(local_date_time:, location:)
      end

      def parse_document_response(_type, _tracking_number, response)
        DocumentResponse.new(content_type: response.headers['content-type'], data: response.body, request: last_request)
      end

      def parse_locations_response(country:, response:)
        raise ResponseError, 'API Error: Unknown response' if response.blank?

        raise ResponseError, 'API Error: Unknown response' unless response.is_a?(Array)

        locations = response

        locations = locations.map do |location|
          Location.new(
            address1: location['address1'],
            city: location['city'],
            province: location['state'],
            country: ActiveUtils::Country.find(location['countrycd']),
            contact: Contact.new(fax: location['fax'], phone: location['phone'])
          )
        end

        locations.select { |location| location.country == country }
      end

      def parse_pickup_response(response)
        pickup_response = PickupResponse.new(request: last_request, response:)
        pickup_number = response['airbillNumber']

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

        error = response.key?('errorMessage')

        if error.present?
          rate_response.error = ResponseError.new(error)
          return rate_response
        end

        if response['quoteTotal'].blank?
          rate_response.error = ResponseError.new('Cost is blank')
          return rate_response
        end

        transit_days = response['transitDaysTotal']

        charge_line_items = response.dig('chargeLineItems', 'chargeLineItem')
        prices = []

        charge_line_items.each do |charge_line_item|
          cents = (charge_line_item['amount'] * 100).to_i
          next if cents.zero?

          description = charge_line_item_description(charge_line_item)

          prices << Price.new(blame: :api, cents:, description:)
        end

        rate = Rate.new(
          carrier: self,
          carrier_name: name,
          currency: 'USD',
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
        tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)

        actual_delivery_date = nil
        estimated_delivery_date = nil
        receiver_location = nil
        scheduled_delivery_date = nil
        ship_time = nil
        shipper_location = nil

        shipment_events = []

        api_events = response
        api_events.each do |api_event|
          event = nil
          EVENTS[:types].each do |key, val|
            if api_event['statusCode'].upcase == val
              event = key
              break
            end
          end
          next if event.blank?

          location = Location.new(
            city: api_event['city'].titleize,
            province: api_event['state'].upcase,
            postal_code: api_event['zip'].upcase,
            country: ActiveUtils::Country.find(api_event['country'])
          )

          date_time = parse_api_date_time(api_event['recordDate'], location)

          api_estimated_delivery_date = api_event['estimatedArrivalDate']
          estimated_delivery_date = parse_api_date_time(api_estimated_delivery_date, nil)

          case event
          when :delivered
            actual_delivery_date = date_time
            receiver_location = location
          when :delivery_appointment_scheduled
            api_date_time = api_event['scheduledDeliveryFromDate']
            scheduled_delivery_date = parse_api_date_time(api_date_time, location)
          when :picked_up
            ship_time = date_time
            shipper_location = location
          end

          shipment_events << ShipmentEvent.new(date_time:, location:, type_code: event)
        end

        estimated_delivery_date = scheduled_delivery_date if scheduled_delivery_date.present?

        status = shipment_events.last&.type_code

        tracking_number = api_events.last['airbillNumber']

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

        tracking_response
      end
    end
  end
end
