module FreightKit
  module Carriers
    class SoutheasternFreightLines < FreightKit::Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Lexington',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'd032f1fc-0c3d-4717-b9e7-314156374088',
              postal_code: '29073',
              region_abbreviation: 'SC',
              street: '420 Davega Rd'
            )
          ]
        end

        def contacts
          [Contact.new(department: 'Main', id: 'da295604-b58b-4f48-bdfa-3bfea8c9514e', phone: '+18006377335')]
        end

        def find_rates_with_declared_value? = true

        def headquarters
          Address.new(
            city: 'Lexington',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '13399c8d-ffaf-4e3b-b9ee-872b3b964308',
            postal_code: '29073',
            region_abbreviation: 'SC',
            street: '420 Davega Rd'
          )
        end

        def id = '4f076fd0-ed4f-4e66-9cfe-9c880c9db8ca'
        def legal_name = 'Southeastern Freight Lines LLC'

        def mappable_accessorials
          {
            airport_delivery: 'chkAPD',
            airport_pickup: 'chkAPU',
            amusement_park_delivery: 'chkLAD',
            amusement_park_pickup: 'chkLAP',
            appointment_delivery: 'chkAN',
            athletic_facility_delivery: 'chkLAD',
            athletic_facility_pickup: 'chkLAP',
            cemetery_delivery: 'chkLAD',
            cemetery_pickup: 'chkLAP',
            church_delivery: 'chkLAD',
            church_pickup: 'chkLAP',
            construction_delivery: 'chkLAD',
            construction_pickup: 'chkLAP',
            convention_delivery: 'chkLAD',
            convention_pickup: 'chkLAP',
            dock_dropoff: 'chkSHC',
            fair_delivery: 'chkLAD',
            fair_pickup: 'chkLAP',
            farm_delivery: 'chkLAD',
            farm_pickup: 'chkLAP',
            fitness_center_delivery: 'chkLAD',
            fitness_center_pickup: 'chkLAP',
            golf_course_delivery: 'chkLAD',
            golf_course_pickup: 'chkLAP',
            government_delivery: 'chkLAD',
            government_pickup: 'chkLAP',
            grocery_store_delivery: 'chkLAD',
            grocery_store_pickup: 'chkLAP',
            guaranteed_delivery: 'chkDG',
            guaranteed_delivery_am: 'chkNG',
            guaranteed_delivery_pm: 'chkDG',
            hospital_delivery: 'chkLAD',
            hospital_pickup: 'chkLAP',
            hotel_delivery: 'chkLAD',
            hotel_pickup: 'chkLAP',
            inside_delivery: 'chkID',
            inside_pickup: 'chkIP',
            inspection_site_delivery: 'chkLAD',
            inspection_site_pickup: 'chkLAP',
            jobsite_delivery: 'chkLAD',
            jobsite_pickup: 'chkLAP',
            liftgate_delivery: 'chkLGD',
            liftgate_pickup: 'chkLGP',
            mall_delivery: 'chkLAD',
            mall_pickup: 'chkLAP',
            marina_delivery: 'chkLAD',
            marina_pickup: 'chkLAP',
            military_site_delivery: 'chkLAD',
            military_site_pickup: 'chkLAP',
            mine_site_delivery: 'chkLAD',
            mine_site_pickup: 'chkLAP',
            motel_delivery: 'chkLAD',
            motel_pickup: 'chkLAP',
            nursing_home_delivery: 'chkLAD',
            nursing_home_pickup: 'chkLAP',
            park_delivery: 'chkLAD',
            park_pickup: 'chkLAP',
            prison_delivery: 'chkLAD',
            prison_pickup: 'chkLAP',
            ranch_delivery: 'chkLAD',
            ranch_pickup: 'chkLAP',
            reservation_delivery: 'chkLAD',
            reservation_pickup: 'chkLAP',
            residential_delivery: 'chkPR',
            residential_pickup: 'chkPR',
            resort_delivery: 'chkLAD',
            resort_pickup: 'chkLAP',
            restaurant_delivery: 'chkLAD',
            restaurant_pickup: 'chkLAP',
            school_delivery: 'chkLAD',
            school_pickup: 'chkLAP',
            steel_mill_delivery: 'chkLAD',
            steel_mill_pickup: 'chkLAP',
            storage_facility_delivery: 'chkLAD',
            storage_facility_pickup: 'chkLAP',
            university_delivery: 'chkLAD',
            university_pickup: 'chkLAP',
            utility_site_delivery: 'chkLAD',
            utility_site_pickup: 'chkLAP'
          }
        end

        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(8, :feet)
        def name = 'Southeastern Freight Lines'
        def overlength_fees_require_tariff? = false
        def required_credential_types = %i[api]
        def requirements = %i[credentials]
        def scac = 'SEFL'
        def services = %i[standard]
        def unquotable_accessorials = %i[dock_pickup]

        def unserviceable_accessorials
          %i[
            afterhours_delivery
            afterhours_pickup
            appointment_pickup
            brewery_delivery
            brewery_pickup
            customs_brokerage
            driver_assist
            early_morning_delivery
            early_morning_pickup
            flatbed_delivery
            flatbed_pickup
            grocery_warehouse_delivery
            grocery_warehouse_pickup
            winery_delivery
            winery_pickup
          ]
        end

        def us_dot_number = 63_419
        def website_url = 'https://sefl.com'
      end

      API = {
        domain: 'www.sefl.com',
        endpoints: { rates: '/webconnect/ratequotes/rest/submitQuote' },
        methods: { get_rate: :get, rates: :post },
        use_ssl: false
      }.freeze
      JSON_HEADERS = {
        Accept: 'application/json',
        charset: 'utf-8',
        'Content-Type' => 'application/x-www-form-urlencoded'
      }.freeze

      # Documents

      # Rates
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

      def auth_header
        api_credentials = fetch_credential(:api)
        auth = Base64.strict_encode64("#{api_credentials.username}:#{api_credentials.password}")

        { Authorization: "Basic #{auth}" }
      end

      def base_url = "https://#{API[:domain]}"

      # Rates
      def build_rate_request(shipment:)
        accessorials = []

        if shipment.accessorials.any?
          serviceable_accessorials?(shipment.accessorials)

          shipment
            .accessorials
            .reject { |accessorial| unquotable_accessorials.include?(accessorial) }
            .each do |shipment_accessorial|
              conf_accessorial = mappable_accessorials[shipment_accessorial]

              case conf_accessorial
              when Array then accessorials += conf_accessorial
              when String then accessorials << conf_accessorial
              end
            end
        end

        longest_dimension = shipment.packages.map { |p| [p.width(:inches), p.length(:inches)].max }.max.ceil
        accessorials << 'chkOD' if longest_dimension >= 96

        accessorials.uniq!

        pickup_on = Date.current
        shipment_description = shipment.packages.map(&:description).reject(&:blank?).uniq.join(', ')
        shipment_description = 'Freight All Kinds' if shipment_description.blank?

        api_credentials = fetch_credential(:api)

        body = {
          allowSpot: longest_dimension >= 120 ? 'Y' : 'N',
          CustomerAccount: api_credentials.account.to_i.to_s.rjust(9, '0'),
          CustomerCity: customer_location.city,
          CustomerName: customer_location.contact.company_name,
          CustomerState: customer_location.province,
          CustomerStreet: customer_location.address1,
          CustomerZip: customer_location.postal_code,
          Description: shipment_description,
          DestCountry: 'U',
          DestinationCity: shipment.destination.city,
          DestinationState: shipment.destination.province,
          DestinationZip: shipment.destination.postal_code,
          DimsOption: 'I',
          EmailAddress: customer_location.contact.email,
          Option: 'T',
          OrigCountry: 'U',
          OriginCity: shipment.origin.city,
          OriginState: shipment.origin.province,
          OriginZip: shipment.origin.postal_code,
          PickupDay: pickup_on.strftime('%_d'),
          PickupMonth: pickup_on.strftime('%_m'),
          PickupYear: pickup_on.strftime('%Y'),
          rateXML: 'Y',
          returnX: 'Y',
          Terms: 'P'
        }

        declared_value = if shipment.declared_value_cents.blank?
                           0
                         else
                           (shipment.declared_value_cents.to_f / 100).ceil
                         end

        body.deep_merge!({ chkIN: 'on', FVInsuranceAmount: format('%.2f', declared_value) }) if declared_value.positive?
        body.deep_merge!({ ODLength: longest_dimension, ODLengthUnit: 'I' }) if longest_dimension >= 96

        cubic_ft_required = shipment.destination.province.upcase == 'PR'

        i = 0
        shipment.packages.each do |package|
          package.quantity.times do
            i += 1

            body = body.deep_merge({ "Class#{i}": package.freight_class.to_s.sub('.', '').to_i })
            body = body.deep_merge({ "Description#{i}": package.description || 'Freight' })
            body = body.deep_merge({ "PieceLength#{i}": package.length(:in).ceil })
            body = body.deep_merge({ "PieceWidth#{i}": package.width(:in).ceil })
            body = body.deep_merge({ "PieceHeight#{i}": package.height(:in).ceil })
            body = body.deep_merge({ "Weight#{i}": package.pounds(:each).ceil })

            body = body.deep_merge({ "CubicFt#{i}": package.cubic_ft(:each) }) if cubic_ft_required
          end
        end

        if accessorials.any?
          body[:accessorial] = 'on'

          accessorials.each { |accessorial| body[accessorial] = 'on' }
        end

        request = build_request(:rates, body:)
        save_request(request)
        request
      end

      def build_request(action, options = {})
        headers = JSON_HEADERS
        headers = headers.merge(auth_header)
        headers = headers.merge(options[:headers]) if options[:headers].present?
        body = URI.encode_www_form(options[:body]) if options[:body].present?

        request = {
          url: options[:url].presence || build_url(action),
          headers:,
          method: API.dig(:methods, action),
          body:
        }

        save_request(request)
        request
      end

      def build_url(action) = "#{base_url}#{API.dig(:endpoints, action)}"

      def commit(request)
        url = request[:url]
        headers = request[:headers]
        method = request[:method]
        body = request[:body]

        case method
        when :post
          HTTPClient.post(url, headers:, body:)
        else
          HTTPClient.get(url, headers:)
        end
      end

      def parse_rate_response(shipment:, response:, tries: 0)
        rate_response = RateResponse.new(request: last_request, response:)

        # Used begin rescue block's retry instead.
        # if tries > 10
        #   rate_response.error = ResponseError.new("Timeout after #{tries * 5} seconds")
        #   return rate_response
        # end

        if response.body.blank?
          rate_response.error = InvalidCredentialsError if response.code == 401

          rate_response.error = ResponseError.new('Unknown response') if rate_response.error.blank?
          return rate_response
        end

        begin
          response = JSON.parse(response.body)
        rescue JSON::ParserError
          sleep(5)
          if tries > 10
            rate_response.error = ResponseError.new("Timeout after #{tries * 5} seconds")
            return rate_response
          end

          tries += 1
          retry
        end

        error = response['errorMessage']

        if error.present?
          rate_response.error = UnserviceableError.new(error.sub(' by SEFL.', '')) if error.include?('one point must be directly serviced')

          rate_response.error = ResponseError.new(error) if rate_response.error.blank?
          return rate_response
        end

        url = response['detailQuoteLocation'].gsub('\\', '')
        request = build_request(:get_rate, url:)

        tries = 0

        until tries > 10
          save_request(request)
          response = commit(request)

          if response.body.blank?
            rate_response.error = InvalidCredentialsError if response.code == 401

            rate_response.error = ResponseError.new('Unknown response') if rate_response.error.blank?
            return rate_response
          end

          response = JSON.parse(response.body)

          if response.blank?
            rate_response.error = ResponseError.new('Unknown response')
            return rate_response
          end

          error = response['errorMessage']

          if error.present?
            if error.downcase.include?('not yet been processed')
              sleep(5)
              tries += 1
              next
            else
              rate_response.error = ResponseError.new(error)
              return rate_response
            end
          end

          tries = 50
        end

        if response['rateQuote'].blank?
          rate_response.error = ResponseError.new('Cost is empty')
          return rate_response
        end

        estimate_reference = response['quoteNumber']
        transit_days = response['transitTime'].to_i

        details = response['details']
        prices = []

        # return details

        details.each do |detail|
          next if detail['typeCharge'].include?('TTL') || detail['typeCharge'].include?('NFC')

          cents = detail['charges'].squish
          cents = cents.blank? ? 0 : (cents.to_f * 100).to_i
          next if cents.zero?

          description = detail['description'].squish

          cents *= -1 if detail['description'].include?('DISCOUNT')

          prices << Price.new(blame: :api, cents:, description:)
        end

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

      # Tracking
    end
  end
end
