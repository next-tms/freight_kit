module FreightKit
  module Carriers
    class XPOLogistics < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Chicago',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '6a957fa1-73cd-417c-a0f7-cc4531cd5570',
              postal_code: '60673',
              region_abbreviation: 'IL',
              street: '29559 Network Pl'
            )
          ]
        end

        def contacts
          [
            Contact.new(
              department: 'Customer Service - Kingman, AZ',
              id: '5bb9caaa-ae84-4ee6-90ef-3c14f6d434c6',
              phone: '+17609228255'
            )
          ]
        end

        def headquarters
          Address.new(
            city: 'Ann Arbor',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '17cbf3e9-ca23-4591-9363-4a0abd7aa5c5',
            postal_code: '48105-2963',
            region_abbreviation: 'MI',
            street: '2211 Old Earhart Rd'
          )
        end

        def id = '5ca40fc0-a4f0-444c-a300-d794336b8216'
        def legal_name = 'XPO Logistics Freight Inc'

        def mappable_accessorials
          {
            afterhours_delivery: 'DAH',
            airport_delivery: 'DMS',
            appointment_delivery: 'APT',
            construction_delivery: 'CSD',
            construction_pickup: 'OCS',
            convention_delivery: 'PED',
            convention_pickup: 'PEO',
            fair_delivery: 'PED',
            fair_pickup: 'PEO',
            government_delivery: 'DMS',
            guaranteed_delivery_am: 'G12',
            guaranteed_delivery: 'GUR',
            inside_delivery: 'DID',
            inside_pickup: 'OIP',
            jobsite_delivery: 'CSD',
            jobsite_pickup: 'OCS',
            liftgate_delivery: 'DLG',
            liftgate_pickup: 'OLG',
            marina_delivery: 'DPW',
            mine_site_delivery: 'DMS',
            residential_delivery: 'RSD',
            residential_pickup: 'RSO'
          }
        end

        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(8, :feet)
        def name = 'XPO Logistics'
        def overlength_fees_require_tariff? = false
        def required_credential_types = %i[api api_key]
        def requirements = %i[credentials]
        def scac = 'CNWY'
        def services = %i[standard]

        def unserviceable_accessorials
          %i[
            afterhours_pickup
            airport_pickup
            amusement_park_delivery
            amusement_park_pickup
            appointment_pickup
            athletic_facility_delivery
            athletic_facility_pickup
            brewery_delivery
            brewery_pickup
            cemetery_delivery
            cemetery_pickup
            church_delivery
            church_pickup
            customs_brokerage
            dock_dropoff
            dock_pickup
            driver_assist
            early_morning_delivery
            early_morning_pickup
            farm_delivery
            farm_pickup
            fitness_center_delivery
            fitness_center_pickup
            flatbed_delivery
            flatbed_pickup
            golf_course_delivery
            golf_course_pickup
            government_pickup
            grocery_store_delivery
            grocery_store_pickup
            grocery_warehouse_delivery
            grocery_warehouse_pickup
            guaranteed_delivery_pm
            hospital_delivery
            hospital_pickup
            hotel_delivery
            hotel_pickup
            inspection_site_delivery
            inspection_site_pickup
            mall_delivery
            mall_pickup
            marina_pickup
            military_site_delivery
            military_site_pickup
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

        def us_dot_number = 241_829
        def us_mc_number = 165_377
        def website_url = 'https://www.xpo.com'
      end

      API = {
        domain: 'api.ltl.xpo.com',
        endpoints: { rates: '/rating/1.0/ratequotes', token: '/token' },
        use_ssl: true
      }.freeze

      # Documents

      # Pickups

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

      def bearer_token = @bearer_token ||= commit(build_bearer_token_request)[:access_token]

      def build_accessorials(shipment:)
        serviceable_accessorials?(shipment.accessorials)

        accessorial_codes = []
        accessorial_codes << 'SSC'
        accessorial_codes << 'ZHM' if shipment.hazmat?

        if shipment.destination.province.upcase == 'HI'
          accessorial_codes = accessorial_codes.map { |code| ['DID', 'OIP'].include?(code) ? 'WHN' : code }.uniq
        end

        longest_dimension_in = shipment.packages.map { |p| [p.width(:inch), p.length(:inch)].max }.max.ceil

        # Switch to accessorials rather than accessorial_codes since now we need more complex structures

        accessorials = accessorial_codes.map { |accessorial_code| { accessorial_cd: accessorial_code, quantity: 0 } }

        return accessorials if longest_dimension_in < 96 && shipment.accessorials.blank?

        accessorials << { accessorial_cd: 'ELS', quantity_uom: 'INCH', quantity: longest_dimension_in } if longest_dimension_in >= 96

        return accessorials if shipment.accessorials.blank?

        shipment.accessorials.map do |accessorial|
          next if unquotable_accessorials.include?(accessorial)

          accessorials << { accessorial_cd: mappable_accessorials[accessorial], quantity: 0 }
        end

        accessorials
      end

      def build_bearer_token_request
        api_credentials = fetch_credential(:api)

        body = URI.encode_www_form(
          grant_type: 'password',
          password: api_credentials.password,
          username: api_credentials.username
        )

        {
          body:,
          headers: {
            authorization: "Basic #{api_credentials.api_key}",
            content_type: 'application/x-www-form-urlencoded'
          },
          method: :post,
          url: build_url(:token)
        }
      end

      def build_commodity(shipment:)
        shipment.packages.map do |package|
          {
            dimensions: {
              dimensions_uom: 'INCH',
              height: package.inches(:height).ceil,
              length: package.inches(:length).ceil,
              width: package.inches(:width).ceil
            },
            gross_weight: { weight: package.pounds(:total).ceil, weight_uom: 'LBS' },
            hazmat_ind: package.hazmat?,
            nmfc_class: package.freight_class.to_s,
            nmfc_item_cd: package.nmfc,
            piece_cnt: package.quantity
          }
        end
      end

      def build_headers
        { accept: 'application/json', authorization: "Bearer #{bearer_token}", 'Content-Type': 'application/json' }
      end

      def build_rate_request(shipment:)
        api_credentials = fetch_credential(:api)
        shipment_date = shipment.pickup_at.date_time_with_zone.iso8601

        accessorials = build_accessorials(shipment:)
        commodity = build_commodity(shipment:)

        body = {
          shipmentInfo: {
            accessorials:,
            bill_2_party: { acct_inst_id: api_credentials.account },
            commodity:,
            consignee: { address: { postal_cd: shipment.destination.postal_code.to_s } },
            pallet_cnt: shipment.packages.map(&:packaging).map(&:pallet?).count(true),
            payment_term_cd: 'P', # prepaid,
            shipment_date:,
            shipper: { address: { postal_cd: shipment.origin.postal_code.to_s } }
          }
        }.deep_transform_keys! { |key| key.to_s.camelize(:lower) }.to_json

        request = { body:, headers: build_headers, method: :post, url: build_url(:rates) }

        save_request(request)
        request
      end

      def build_url(action)
        scheme = API[:use_ssl] ? 'https://' : 'http://'
        "#{scheme}#{API[:domain]}#{API.dig(:endpoints, action)}"
      end

      def commit(request)
        url = request[:url]
        headers = request[:headers] || build_headers
        method = request[:method]
        body = request[:body]

        response = case method
                   when :post
                     HTTPClient.post(url, headers:, body:)
                   else
                     HTTPClient.get(url, headers:)
                   end

        begin
          json = JSON.parse(response.body).deep_symbolize_keys
        rescue JSON::ParserError => e
          # CNWY returns a string during runtime/server error
          raise FreightKit::ResponseError, 'Runtime Error' if response.body.include?('Runtime Error')

          raise e
        end

        error = (json[:error_description] || json.dig(:fault, :description) || json.dig(:error, :message) if json.is_a?(Hash))

        if error.blank?
          return json if (200..299).include?(response.code)
        else
          case response.code
          when 401
            raise FreightKit::InvalidCredentialsError
          end
        end

        raise FreightKit::ResponseError, error
      end

      def parse_amount(amount) = (amount.to_f * 100).to_i

      def parse_rate_response(shipment:, response:)
        rate_response = RateResponse.new(request: last_request, response:)

        if response.blank?
          rate_response.error = ResponseError.new('Unknown response')
          return rate_response
        end

        if response.dig(:data, :rateQuote, :totCharge, 0, :amt).blank?
          rate_response.error = ResponseError.new('Cost is empty')
          return rate_response
        end

        accessorials = response.dig(:data, :rateQuote, :shipmentInfo, :accessorials)
        commodities = response.dig(:data, :rateQuote, :shipmentInfo, :commodity)
        deficit_weight = response.dig(:data, :rateQuote, :deficitRatingInfo)

        prices = []

        prices << FreightKit::Price.new(
          blame: :api,
          cents: parse_amount(commodities.sum { |c| c.dig(:charge, :chargeAmt, :amt) }),
          description: 'Freight'
        )

        if deficit_weight.present?
          prices << FreightKit::Price.new(
            blame: :api,
            cents: parse_amount(deficit_weight.dig(:deficitAmt, :amt)),
            description: <<~DESC.squish
              Deficit weight
              #{deficit_weight.dig(:deficitWght, :weight).ceil}
              #{deficit_weight.dig(:deficitWght, :weightUom).downcase}
            DESC
          )
        end

        prices << FreightKit::Price.new(
          blame: :api,
          cents: parse_amount(response.dig(:data, :rateQuote, :totDiscountAmt, :amt)) * -1,
          description: "Discount #{response.dig(:data, :rateQuote, :actlDiscountPct)}%"
        )

        prices += accessorials.map do |accessorial|
          FreightKit::Price.new(
            blame: :api,
            cents: parse_amount(accessorial.dig(:chargeAmt, :amt)),
            description: accessorial[:accessorialDesc].squish.capitalize.gsub('Xpo', 'XPO')
          )
        end

        comment = response.dig(:data, :rateQuote, :shipmentInfo, :comment)
        days = if comment.blank?
                 nil
               else
                 comment[/(\d+) days/, 1]&.to_i
               end

        expires_at = if days.is_a?(Integer) && days.positive?
                       days.days.from_now
                     else
                       2.days.from_now
                     end

        estimate_reference = response.dig(:data, :rateQuote, :confirmationNbr)
        transit_days = response.dig(:data, :transitTime, :transitDays)

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

      def request_url(action)
        scheme = API.dig(:use_ssl, action) ? 'https://' : 'http://'
        "#{scheme}#{API.dig(:domains, action)}#{API.dig(:endpoints, action)}"
      end

      # Tracking
    end
  end
end
