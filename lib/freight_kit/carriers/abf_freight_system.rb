module FreightKit
  module Carriers
    class ABFFreightSystem < FreightKit::Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'ea41c709-cf46-4958-9a19-c78d7266ed6d', phone: '+18007556486')]
        end

        def find_rates_with_declared_value? = true

        def headquarters
          Address.new(
            city: 'Fort Smith',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '9f83d523-a6dc-495b-b14e-06fc7e63daec',
            postal_code: '72903-5937',
            region_abbreviation: 'AR',
            street: '3801 Old Greenwood Rd'
          )
        end

        def id = 'bbbe2213-850b-4230-9211-14cf190ee1d1'
        def legal_name = 'ABF Freight System Inc'
        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(150, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(6, :feet)
        def name = 'ABF Freight System'
        def overlength_fees_require_tariff? = false
        def pickup_number_is_tracking_number? = true
        def required_credential_types = %i[api api_key]
        def requirements = %i[credentials]
        def scac = 'ABFS'

        def serviceable_accessorials?(accessorials)
          unsupported_accessorials = unserviceable_accessorials.select do |key|
            accessorials.include?(key)
          end.sort!

          message = "#{unsupported_accessorials.join(', ')} unserviceable"
          raise FreightKit::UnserviceableError, message if unsupported_accessorials.any?

          true
        end

        def services = %i[standard]

        def unserviceable_accessorials
          %i[
            afterhours_delivery
            afterhours_pickup
            appointment_delivery
            appointment_pickup
            athletic_facility_delivery
            athletic_facility_pickup
            brewery_delivery
            brewery_pickup
            construction_site_pickup
            customs_brokerage
            dock_dropoff
            dock_pickup
            driver_assist
            early_morning_delivery
            early_morning_pickup
            fitness_center_delivery
            fitness_center_pickup
            flatbed_delivery
            flatbed_pickup
            gated_community_delivery
            gated_community_pickup
            grocery_store_delivery
            grocery_store_pickup
            grocery_warehouse_delivery
            grocery_warehouse_pickup
            guaranteed_delivery
            guaranteed_delivery_am
            guaranteed_delivery_pm
            hotel_delivery
            hotel_pickup
            inspection_site_delivery
            inspection_site_pickup
            jobsite_delivery
            jobsite_pickup
            mall_delivery
            mall_pickup
            marina_delivery
            marina_pickup
            motel_delivery
            motel_pickup
            residential_delivery
            residential_pickup
            resort_delivery
            resort_pickup
            steel_mill_delivery
            steel_mill_pickup
            winery_delivery
            winery_pickup
          ]
        end

        def us_dot_number = 82_866
        def us_mc_number = 29_910

        def validate_packages(packages)
          # @note This doesn't refer to package quantities, instead it referes to maximum number of package-related URL
          # query params
          raise FreightKit::UnserviceableError, 'Too many packages' if packages.count > 15

          unsupported_packaging_types = packages.map(&:packaging).map(&:type).select do |type|
            PACKAGE_TYPES.keys.exclude?(type)
          end.sort!

          message = "#{unsupported_packaging_types.join(', ').upcase_first} unserviceable"
          raise FreightKit::UnserviceableError, message if unsupported_packaging_types.any?

          true
        end

        def website_url = 'https://arcb.com'
      end

      API = { domain: 'www.abfs.com', endpoints: { rates: '/xml/aquotexml.asp' }, methods: { rates: 'GET' } }.freeze
      DELIVERY_LIMITED_ACCESS_TYPES = {
        airport_delivery: 'O',
        amusement_park_delivery: 'O',
        cemetery_delivery: 'O',
        church_delivery: 'C',
        construction_site_delivery: 'O',
        convention_delivery: 'O',
        fair_delivery: 'O',
        farm_delivery: 'O',
        golf_course_delivery: 'O',
        government_delivery: 'O',
        hospital_delivery: 'O',
        liftgate_delivery: 'O',
        military_site_delivery: 'M',
        mine_site_delivery: 'O',
        nursing_home_delivery: 'O',
        park_delivery: 'O',
        prison_delivery: 'O',
        ranch_delivery: 'O',
        reservation_delivery: 'O',
        restaurant_delivery: 'O',
        school_delivery: 'S',
        storage_facility_delivery: 'U',
        university_delivery: 'O',
        utility_site_delivery: 'O'
      }.freeze
      PACKAGE_TYPES = {
        box: 'BX',
        bundle: 'BDL',
        crate: 'CRT',
        cylinder: 'CYL',
        drum: 'DR',
        luggage: 'PC',
        pail: 'PL',
        pallet: 'PLT',
        piece: 'PC',
        roll: 'RL',
        tote: 'TOTE'
      }.freeze
      PICKUP_LIMITED_ACCESS_TYPES = {
        airport_pickup: 'O',
        amusement_park_pickup: 'O',
        cemetery_pickup: 'O',
        church_pickup: 'C',
        convention_pickup: 'O',
        fair_pickup: 'O',
        farm_pickup: 'O',
        golf_course_pickup: 'O',
        government_pickup: 'O',
        hospital_pickup: 'O',
        liftgate_pickup: 'Acc_GRD_PU',
        military_site_pickup: 'M',
        mine_site_pickup: 'O',
        nursing_home_pickup: 'O',
        park_pickup: 'O',
        prison_pickup: 'O',
        ranch_pickup: 'O',
        reservation_pickup: 'O',
        restaurant_pickup: 'O',
        school_pickup: 'S',
        storage_facility_pickup: 'U',
        university_pickup: 'O',
        utility_site_pickup: 'O'
      }.freeze
      XML_HEADERS = { 'Accept' => 'application/xml', 'charset' => 'utf-8', 'Content-Type' => 'application/xml' }.freeze

      # Documents

      # Pickups

      # Rates

      def find_rates(shipment:)
        begin
          serviceable_accessorials?(shipment.accessorials)
          validate_packages(shipment.packages)
        rescue UnserviceableError => e
          return RateResponse.new(error: e)
        end

        request = build_rate_request(shipment:)
        # commit(request)
        parse_rate_response(shipment:, response: commit(request))
      end

      # Tracking

      protected

      def build_rate_request(shipment:)
        broker_credential = fetch_credential(:api)
        tms_credential = fetch_credential(:api_key)

        account = { 'ID' => broker_credential.username }
        account['APP_ID'] = tms_credential.api_key

        delivery = {}.tap do |builder|
          delivery_limited_access_type = DELIVERY_LIMITED_ACCESS_TYPES.values_at(*shipment.accessorials).first

          if delivery_limited_access_type.present?
            builder['Acc_LAD'] = 'Y'
            builder['LADType'] = delivery_limited_access_type
          end

          builder['Acc_CSD'] = 'Y' if shipment.accessorials.include?(:construction_site_delivery)
          builder['Acc_GRD_DEL'] = 'Y' if shipment.accessorials.include?(:liftgate_delivery)
          builder['Acc_IDEL'] = 'Y' if shipment.accessorials.include?(:inside_delivery)
          builder['Acc_RDEL'] = 'Y' if shipment.accessorials.include?(:residential_delivery)

          if shipment.accessorials.include?(:convention_delivery)
            builder['Acc_TRDSHWD'] = 'Y'
            builder['TRDSHWDType'] = 'DTS' if shipment.accessorials.include?(:convention_delivery)
          end
        end

        pickup = {}.tap do |builder|
          pickup_limited_access_type = PICKUP_LIMITED_ACCESS_TYPES.values_at(*shipment.accessorials).first

          if pickup_limited_access_type.present?
            builder['Acc_LAP'] = 'Y'
            builder['LAPType'] = pickup_limited_access_type
          end

          builder['Acc_GRD_PU'] = 'Y' if shipment.accessorials.include?(:liftgate_pickup)
          builder['Acc_IPU'] = 'Y' if shipment.accessorials.include?(:inside_pickup)
          builder['Acc_RPU'] = 'Y' if shipment.accessorials.include?(:residential_pickup)
          builder['Acc_TRDSHWO'] = 'DTS' if shipment.accessorials.include?(:convention_pickup)
        end

        shipper = {
          'ShipCity' => shipment.origin.city,
          'ShipState' => shipment.origin.province,
          'ShipZip' => shipment.origin.postal_code,
          'ShipCountry' => shipment.origin.country.code(:alpha2).value
        }

        consignee = {
          'ConsCity' => shipment.destination.city,
          'ConsState' => shipment.destination.province,
          'ConsZip' => shipment.destination.postal_code,
          'ConsCountry' => shipment.destination.country.code(:alpha2).value
        }

        third_party = {
          'TPBAcct' => broker_credential.account,
          'TPBAddr' => [customer_location.address1, customer_location.address2].compact.join(', '),
          'TPBAff' => 'Y',
          'TPBCity' => customer_location.city,
          'TPBCountry' => customer_location.country.code(:alpha2).value,
          'TPBName' => customer_location.contact&.company_name,
          'TPBPay' => 'Y',
          'TPBState' => customer_location.province,
          'TPBZip' => customer_location.postal_code
        }
                      .compact_blank!

        shipment.packages.map { |p| p.pounds(:total).ceil }.sum

        commodities = shipment.packages.map.with_index do |package, i|
          {
            "Class#{i + 1}" => package.freight_class,
            "FrtHght#{i + 1}" => package.inches(:height),
            "FrtLng#{i + 1}" => package.inches(:length),
            "FrtWdth#{i + 1}" => package.inches(:width),
            "UnitNo#{i + 1}" => package.quantity,
            "UnitType#{i + 1}" => PACKAGE_TYPES[package.packaging.type],
            "Wgt#{i + 1}" => package.pounds(:total)
          }
        end
        commodities = commodities.reduce({}, :merge)

        # @note API won't accept any other date
        time = Time.current.in_time_zone('America/Chicago')

        specifics = {
          'FrtLWHType' => 'IN',
          'ShipMonth' => time.strftime('%m'),
          'ShipDay' => time.strftime('%d'),
          'ShipYear' => time.strftime('%Y')
        }

        if shipment.packages.map { |package| package.cubic_ft(:each) }.all?(&:present?)
          specifics['Cube'] = shipment.packages.sum { |package| package.cubic_ft(:each) }.ceil
        end

        other_options = {}.tap do |builder|
          alpha2_codes = [shipment.destination.country, shipment.origin.country].map do |country|
            country.code(:alpha2).value
          end

          builder['Acc_ARR'] = 'Y' if shipment.accessorials.include?(:appointment_delivery)

          if alpha2_codes.any? { |alpha2_code| alpha2_code == 'US' } &&
             alpha2_codes.any? { |alpha2_code| alpha2_code != 'US' }
            builder['Acc_BOND'] = 'Y'
          end

          unless shipment.accessorials.intersect?(%i[
                                                    church_delivery
                                                    inside_delivery
                                                    liftgate_delivery
                                                    residential_delivery
                                                    restaurant_delivery
                                                  ])
            builder['Acc_CUL'] = 'Y'
          end

          builder['Acc_HAZ'] = 'Y' if shipment.packages.any?(&:hazmat?)
          builder['Acc_PALLET'] = 'Y' if shipment.packages.map(&:packaging).all?(&:pallet?)

          unless shipment.accessorials.intersect?(%i[
                                                    church_pickup
                                                    inside_pickup
                                                    liftgate_pickup
                                                    residential_pickup
                                                    restaurant_pickup
                                                  ])
            builder['Acc_SL'] = 'Y'
          end

          builder['Acc_SS'] = 'Y'

          longest_dimension_in = if shipment.packages.all? do |package|
                                      package.length(:inch).present? && package.width(:inch).present?
                                    end

                                   shipment.packages.map do |package|
                                     [package.length(:in), package.width(:in)].max
                                   end.max.ceil
                                 end

          if longest_dimension_in.present?
            builder['ODLongestSide'] = longest_dimension_in

            if longest_dimension_in >= 96
              builder['Acc_OD'] = 'Y'

              builder['Acc_CAP'] = 'Y' if longest_dimension_in >= 336
            end
          end

          if shipment.declared_value_cents.present? && shipment.declared_value_cents.positive?
            builder['Acc_ELC'] = 'Y'
            builder['DeclaredType'] = 'N'
            builder['DeclaredValue'] = (shipment.declared_value_cents / 100).ceil
          end
        end

        params = [account, commodities, consignee, delivery, other_options, pickup, shipper, specifics, third_party]
                 .reduce({}, :merge)

        build_request(:rates, { params: })
      end

      def build_request(action, options = {})
        request = { url: build_url(action, options), headers: XML_HEADERS, method: API.dig(:methods, action) }

        save_request(request)
        request
      end

      def build_url(action, options = {})
        uri = URI.parse("https://#{API[:domain]}#{API.dig(:endpoints, action)}")
        uri.query = options[:params].to_query if options[:params].present?

        uri.to_s
      end

      def commit(request)
        body = request[:body]
        headers = request[:headers]
        method = request[:method]
        url = request[:url]

        response = if method == :post
                     HTTPClient.post(url, headers:, body:)
                   else
                     HTTPClient.get(url, headers:)
                   end

        response.deep_transform_keys! { |key| key.downcase.to_sym }[:abf] if response&.parsed_response
      end

      def parse_rate_response(shipment:, response:)
        rate_response = RateResponse.new(request: last_request, response:)

        error_count = response[:numerrors].to_i
        if error_count.positive?
          # response.dig(:error, :errorcode).to_i

          message = response.dig(:error, :errormessage)
          rate_response.error = ResponseError.new(message)
          return rate_response
        end

        if response[:charge].blank?
          rate_response.error = ResponseError.new('Cost is blank')
          return rate_response
        end

        estimate_reference = response[:quoteid]
        included_charges = response[:includedcharges].compact_blank!.keys
        transit_days = response[:standard_service_days].to_i

        rates = [].tap do |builder|
          cents = (response[:charge].to_f * 100).to_i
          transit_days = parse_transit_duration(response[:shipdate], response[:advertisedduedate])
          with_excessive_length_fees = included_charges.include?(:overdimension)

          builder << Rate.new(
            carrier: self,
            carrier_name: name,
            currency: 'USD',
            estimate_reference:,
            scac:,
            service_name: :standard,
            shipment:,
            prices: [Price.new(blame: :api, cents:, description: 'Freight')],
            transit_days:,
            with_excessive_length_fees:
          )

          guaranteed_options = response.dig(:guaranteedoptions, :option)

          if guaranteed_options.is_a?(Array)
            guaranteed_options.each do |guaranteed_option|
              cents = (guaranteed_option[:guaranteedcharge].to_f * 100).to_i
              service_name = guaranteed_ltl_service(guaranteed_option[:guaranteedbytime])
              transit_days = parse_transit_duration(response[:shipdate], guaranteed_option[:guaranteeddeldate])

              builder << Rate.new(
                carrier: self,
                carrier_name: name,
                currency: 'USD',
                estimate_reference:,
                scac:,
                service_name:,
                shipment:,
                prices: [Price.new(blame: :api, cents:, description: 'Freight')],
                transit_days:,
                with_excessive_length_fees:
              )
            end
          end
        end

        rate_response.rates = rates
        rate_response
      end

      # Tracking

      private

      def guaranteed_ltl_service(hours)
        raise ArgumentError, 'Invalid hours' unless hours.match?(/^\d{4}$/)

        return :guaranteed_ltl_am if hours[0..1].to_i <= 12

        :guaranteed_ltl
      end

      def parse_transit_duration(from, to)
        from = ::Time.parse(from).in_time_zone('America/Chicago')
        to = ::Time.parse(to).in_time_zone('America/Chicago')

        (from.business_time_until(to) / 28_800.0).days
      end
    end
  end
end
