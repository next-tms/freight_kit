module FreightKit
  module Carriers
    class Saia < FreightKit::Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Dallas',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '85c2c731-88c3-4768-808a-858fff783fa2',
              postal_code: '75373',
              region_abbreviation: 'TX',
              street: 'PO Box 730532',
              street2: '800 765 7242'
            )
          ]
        end

        def contacts
          [Contact.new(department: 'Main', id: '8c2b4da9-b91a-4b72-a7df-6e21c3f12018', phone: '+17702325067')]
        end

        def find_rates_with_declared_value? = true

        def headquarters
          Address.new(
            city: 'Johns Creek',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '6d40ce8f-c88a-418e-b29d-db4c3239c945',
            postal_code: '30097',
            region_abbreviation: 'GA',
            street: '11465 Johns Creek Pkwy Ste 400'
          )
        end

        def id = '26a6a0c0-2e95-4835-ad73-4a3c8bb38cdd'
        def legal_name = 'Saia Motor Freight Line LLC'

        def mappable_accessorials
          {
            airport_delivery: 'LimitedAccessLocation',
            airport_pickup: 'LimitedAccessLocationPU',
            amusement_park_delivery: 'LimitedAccessLocation',
            amusement_park_pickup: 'LimitedAccessLocationPU',
            appointment_delivery: 'ArrivalNotice/Appointment',
            cemetery_delivery: 'LimitedAccessLocation',
            cemetery_pickup: 'LimitedAccessLocationPU',
            church_delivery: 'LimitedAccessLocation',
            church_pickup: 'LimitedAccessLocationPU',
            construction_delivery: 'LimitedAccessLocation',
            construction_pickup: 'LimitedAccessLocationPU',
            convention_delivery: 'TradeShowDelivery',
            convention_pickup: 'TradeShowPickup',
            driver_assist: 'WhiteGlove',
            fair_delivery: 'LimitedAccessLocation',
            fair_pickup: 'LimitedAccessLocationPU',
            government_delivery: 'LimitedAccessLocation',
            government_pickup: 'LimitedAccessLocationPU',
            inside_delivery: 'InsideDelivery',
            inside_pickup: 'InsidePickup',
            jobsite_delivery: 'LimitedAccessLocation',
            jobsite_pickup: 'LimitedAccessLocationPU',
            liftgate_delivery: 'LiftgateService',
            liftgate_pickup: 'LiftgateServicePU',
            marina_delivery: 'LimitedAccessLocation',
            marina_pickup: 'LimitedAccessLocationPU',
            military_site_delivery: 'LimitedAccessLocation',
            military_site_pickup: 'LimitedAccessLocationPU',
            mine_site_delivery: 'LimitedAccessLocation',
            mine_site_pickup: 'LimitedAccessLocationPU',
            prison_delivery: 'LimitedAccessLocation',
            prison_pickup: 'LimitedAccessLocationPU',
            residential_delivery: 'ResidentialDelivery',
            residential_pickup: 'ResidentialPickup',
            school_delivery: 'LimitedAccessLocation',
            school_pickup: 'LimitedAccessLocationPU',
            steel_mill_delivery: 'LimitedAccessLocation',
            steel_mill_pickup: 'LimitedAccessLocationPU',
            storage_facility_delivery: 'LimitedAccessLocation',
            storage_facility_pickup: 'LimitedAccessLocationPU',
            university_delivery: 'LimitedAccessLocation',
            university_pickup: 'LimitedAccessLocationPU',
            utility_site_delivery: 'LimitedAccessLocation',
            utility_site_pickup: 'LimitedAccessLocationPU'
          }
        end

        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(8, :feet)
        def name = 'Saia'
        def overlength_fees_require_tariff? = false
        def required_credential_types = %i[api]
        def requirements = %i[credentials]
        def scac = 'SAIA'
        def services = %i[standard guaranteed_delivery guaranteed_delivery_am guaranteed_delivery_pm]

        def unquotable_accessorials
          %i[
            athletic_facility_delivery
            athletic_facility_pickup
            brewery_delivery
            brewery_pickup
            dock_dropoff
            dock_pickup
            farm_delivery
            farm_pickup
            fitness_center_delivery
            fitness_center_pickup
            golf_course_delivery
            golf_course_pickup
            grocery_store_delivery
            grocery_store_pickup
            grocery_warehouse_delivery
            grocery_warehouse_pickup
            hospital_delivery
            hospital_pickup
            hotel_delivery
            hotel_pickup
            inspection_site_delivery
            inspection_site_pickup
            mall_delivery
            mall_pickup
            motel_delivery
            motel_pickup
            nursing_home_delivery
            nursing_home_pickup
            park_delivery
            park_pickup
            ranch_delivery
            ranch_pickup
            reservation_delivery
            reservation_pickup
            resort_delivery
            resort_pickup
            restaurant_delivery
            restaurant_pickup
            winery_delivery
            winery_pickup
          ]
        end

        def unserviceable_accessorials
          %i[
            afterhours_delivery
            afterhours_pickup
            appointment_pickup
            customs_brokerage
            early_morning_delivery
            early_morning_pickup
            flatbed_delivery
            flatbed_pickup
            guaranteed_delivery
            guaranteed_delivery_am
            guaranteed_delivery_pm
          ]
        end

        def us_dot_number = 29_124
        def us_mc_number = 87_511

        def validate_packages(packages, _tariff = nil)
          raise UnserviceableError, 'Must be fewer than 10 items altogether' if packages.sum(&:quantity) > 10

          super
        end

        def website_url = 'https://www.saia.com'
      end

      include FreightKit::Rateable
      include FreightKit::Trackable

      API = {
        actions: { rates: :create, track: :get_by_pro_number },
        domain: 'www.saiasecure.com',
        endpoints: { rates: '/webservice/ratequote/soap.asmx?wsdl', track: '/webservice/shipment/soap.asmx?wsdl' },
        use_ssl: true
      }.freeze
      EVENTS = {
        types: {
          arrived_at_terminal: 'arrived',
          delivered: 'delivered',
          departed: 'departed from terminal',
          located: 'arrived at breakbulk terminal',
          out_for_delivery: 'dispatched for delivery',
          picked_up: 'pickup from customer',
          trailer_unloaded: 'unload trailer',
          trailer_closed: 'load trailer'
        }
      }.freeze

      # Documents

      # Rates

      protected

      # Rates
      def build_rate_request(shipment:)
        accessorials = [{ AccessorialItem: { Code: 'SingleShipment' } }]
        if shipment.accessorials.present?
          serviceable_accessorials?(shipment.accessorials)
          shipment.accessorials.each do |a|
            accessorials << { AccessorialItem: { Code: mappable_accessorials[a] } } if unserviceable_accessorials.exclude?(a)
          end
        end

        longest_dimension = shipment.packages.map { |p| [p.width(:inches), p.length(:inches)].max }.max.ceil
        accessorials << { AccessorialItem: { Code: 'ExcessiveLength' } } if longest_dimension >= 96

        accessorials = accessorials.uniq

        details = []
        dimensions = []
        shipment.packages.each do |package|
          package.quantity.times do
            details << {
              DetailItem: {
                Weight: package.pounds(:each).ceil,
                Class: package.freight_class.to_s,
                Length: package.length(:in).ceil,
                Width: package.width(:in).ceil,
                Height: package.height(:in).ceil
              }
            }

            # Keeping this one at a time to match with "details"
            dimensions << {
              DimensionItem: {
                Units: 1,
                Length: package.length(:in).round(2),
                Width: package.width(:in).round(2),
                Height: package.height(:in).round(2),
                Type: 'IN' # inches
              }
            }
          end
        end

        request = {
          request: {
            Application: 'ThirdParty',
            BillingTerms: 'Prepaid',
            OriginCity: shipment.origin.city,
            OriginState: shipment.origin.province,
            OriginZipcode: shipment.origin.postal_code.to_s.upcase,
            DestinationCity: shipment.destination.city,
            DestinationState: shipment.destination.province,
            DestinationZipcode: shipment.destination.postal_code.to_s.upcase,
            WeightUnits: 'LBS',
            TotalCube: shipment.packages.sum { |p| p.cubic_ft(:each) }.round(2),
            TotalCubeUnits: 'CUFT', # cubic ft
            ExcessiveLengthTotalInches: longest_dimension.to_s,
            Details: details,
            Dimensions: dimensions,
            Accessorials: accessorials
          }
        }

        declared_value = if shipment.declared_value_cents.blank?
                           nil
                         else
                           (shipment.declared_value_cents.to_f / 100).ceil
                         end

        if declared_value.present?
          request = request.deep_merge(
            { request: { DeclaredValue: declared_value, FullValueCoverage: declared_value } }
          )
        end

        save_request(request)
        request
      end

      def build_tracking_request(tracking_number)
        request = { request: { ProNumber: tracking_number } }
        save_request(request)
        request
      end

      def commit(action, request)
        client_args = {
          wsdl: request_url(action),
          convert_request_keys_to: :none,
          env_namespace: :soap,
          element_form_default: :qualified
        }

        call_args = { message: request_blueprint.deep_merge(request) }

        ::FreightKit::SoapClient.new(
          carrier: self,
          action:,
          client_args:,
          call_args:,
          soap_operation: API.dig(:actions, action)
        ).call&.to_hash&.with_indifferent_access
      end

      def parse_api_date_time(date_time, location)
        return if date_time.blank?

        local_date_time = ::Time.strptime(date_time, '%Y-%m-%d %H:%M:%S').to_fs(:db)
        ::FreightKit::DateTime.new(local_date_time:, location:)
      end

      def parse_api_location(api_event)
        Location.new(
          city: api_event[:city]&.titleize,
          province: api_event[:state]&.upcase,
          country: ActiveUtils::Country.find('USA')
        )
      end

      def parse_rate_response(shipment:, response:)
        rate_response = RateResponse.new(request: last_request, response:)

        if response.blank?
          rate_response.error = ResponseError.new('Unknown response')
          return rate_response
        end

        error = response.dig(:create_response, :create_result, :code)

        if error.present?
          message = response.dig(:create_response, :create_result, :message)

          case error
          when 'DNF'
            rate_response.error = UnserviceableError.new("#{error}: #{message}")
            return rate_response
          when 'S10'
            rate_response.error = UnserviceableError.new("#{error}: #{message}")
            return rate_response
          end

          if message.downcase.include?('must not exceed 10 lines')
            rate_response.error = UnserviceableError.new("#{error}: #{message}")
            return rate_response
          end

          rate_response.error = ResponseError.new("#{error}: #{message}")
          return rate_response
        end

        result = response.dig(:create_response, :create_result)

        if result.blank?
          rate_response.error = ResponseError.new('Unknown result')
          return rate_response
        end

        if result[:total_invoice].blank?
          rate_response.error = ResponseError.new('Cost is blank')
          return rate_response
        end

        transit_days = result[:standard_service_days].to_i
        estimate_reference = result[:quote_number]

        rate_accessorial_items = result.dig(:rate_accessorials, :rate_accessorial_item)
        rate_accessorial_items = [rate_accessorial_items] if rate_accessorial_items.is_a?(Hash)

        prices = rate_accessorial_items.map do |rate_accessorial_item|
          Price.new(
            blame: :api,
            cents: (rate_accessorial_item[:amount].to_f * 100).to_i,
            description: rate_accessorial_item[:description]&.titleize&.squish
          )
        end

        standard_ltl_cents = (result[:total_invoice].to_f * 100).to_i - prices.sum(&:cents)

        rates = []

        rates << Rate.new(
          carrier: self,
          carrier_name: name,
          currency: 'USD',
          estimate_reference:,
          scac:,
          service_name: :standard,
          shipment:,
          prices: [Price.new(blame: :api, cents: standard_ltl_cents, description: 'Freight')] + prices,
          transit_days:,
          with_excessive_length_fees: rates_with_excessive_length_fees?
        )

        [
          { guaranteed_ltl: result[:guarantee_amount] },
          { guaranteed_ltl_am: result[:guarantee_amount12pm] },
          { guaranteed_ltl_pm: result[:guarantee_amount2pm] }
        ].each do |service|
          next if service.values[0] == '0' || service.values[0].blank?

          cents = (service.values[0].to_f * 100).to_i

          rates << Rate.new(
            carrier_name: name,
            carrier: self,
            currency: 'USD',
            estimate_reference:,
            scac:,
            service_name: service.keys[0],
            shipment:,
            prices: [Price.new(blame: :api, cents: standard_ltl_cents + cents, description: 'Freight')] + prices,
            with_excessive_length_fees: rates_with_excessive_length_fees?
          )
        end

        rate_response.rates = rates
        rate_response
      end

      def parse_tracking_response(response)
        tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)

        error = if response
                  response.dig(:get_by_pro_number_response, :get_by_pro_number_result, :code)
                else
                  'API Error: Unknown response'
                end

        if error.present?
          tracking_response.error = ResponseError.new(error)
          return tracking_response
        end

        search_result = response.dig(:get_by_pro_number_response, :get_by_pro_number_result)

        if search_result.blank?
          tracking_response.error = ShipmentNotFoundError.new
          return tracking_response
        end

        address1 = [search_result.dig(:shipper, :address1), search_result.dig(:shipper, :address2)]
                   .select(&:present?)
                   .map { |line| line.squish.strip.titleize }
                   .join(', ')

        shipper_location = Location.new(
          address1:,
          city: search_result.dig(:shipper, :city)&.squish&.titleize,
          province: search_result.dig(:shipper, :state)&.strip&.upcase,
          postal_code: search_result.dig(:shipper, :zipcode)&.strip,
          country: ActiveUtils::Country.find('USA')
        )

        address1 = [search_result.dig(:consignee, :address1), search_result.dig(:consignee, :address2)]
                   .select(&:present?)
                   .map { |line| line.squish.strip.titleize }
                   .join(', ')

        receiver_location = Location.new(
          address1:,
          city: search_result.dig(:consignee, :city)&.squish&.titleize,
          province: search_result.dig(:consignee, :state)&.strip&.upcase,
          postal_code: search_result.dig(:consignee, :zipcode)&.strip,
          country: ActiveUtils::Country.find('USA')
        )

        api_date_time = search_result[:delivery_date_time_arrive]
        actual_delivery_date = parse_api_date_time(api_date_time, receiver_location)

        api_date_time = search_result[:pickup_date_time]
        pickup_date = parse_api_date_time(api_date_time, shipper_location)

        api_date_time = search_result[:delivery_appointment_date_time]
        scheduled_delivery_date = parse_api_date_time(api_date_time, receiver_location)

        tracking_number = search_result[:pro_number]

        shipment_events = []

        api_events = search_result.dig(:history, :history_item)

        if api_events.blank?
          shipment_events << ShipmentEvent.new(
            date_time: pickup_date,
            location: shipper_location,
            type_code: :picked_up
          )
        else
          api_events = [api_events] if api_events.is_a?(Hash)

          api_events.each do |api_event|
            event_key = nil
            comment = api_event[:activity]

            EVENTS[:types].each do |key, val|
              if comment.downcase.include?(val)
                event_key = key
                break
              end
            end
            next if event_key.blank?

            api_date_time = api_event[:activity_date_time]

            location = parse_api_location(api_event)
            date_time = parse_api_date_time(api_date_time, location)

            shipment_events << ShipmentEvent.new(date_time:, location:, type_code: event_key)
          end
        end

        status = shipment_events.last&.type_code

        tracking_response.assign_attributes(
          actual_delivery_date:,
          destination: receiver_location,
          origin: shipper_location,
          scheduled_delivery_date:,
          ship_time: pickup_date,
          shipment_events:,
          status:,
          tracking_number:
        )

        tracking_response
      end

      def request_blueprint
        api_credentials = fetch_credential(:api)

        {
          request: {
            AccountNumber: api_credentials.account,
            Application: 'ThirdParty',
            Password: api_credentials.password,
            TestMode: 'N',
            UserID: api_credentials.username
          }
        }
      end

      def request_url(action)
        scheme = API[:use_ssl] ? 'https://' : 'http://'
        "#{scheme}#{API[:domain]}#{API.dig(:endpoints, action)}"
      end
    end
  end
end
