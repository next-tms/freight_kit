module FreightKit
  module Carriers
    class TotalTransportation < Platforms::CarrierLogistics
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Fullerton',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '3438e99a-8b0a-4d56-9f61-19986738eaf1',
              postal_code: '92835',
              region_abbreviation: 'CA',
              street: '210 E Lambert Rd'
            )
          ]
        end

        def id = '2724a897-1f2e-4574-9b9d-2a72332a9dec'

        def mappable_accessorials
          {
            appointment_delivery: 'APPT',
            inside_delivery: 'IDL',
            inside_pickup: 'IDL',
            liftgate_delivery: 'LIFT',
            liftgate_pickup: 'LIFTP',
            residential_delivery: 'RESI',
            residential_pickup: 'RESP',
            restaurant_delivery: ['IDL', 'LIFT'],
            restaurant_pickup: ['IDL', 'LIFTP']
          }
        end

        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(40, :inches)
        def name = 'Total Transportation'
        def overlength_fees_require_tariff? = false
        def pickup_number_is_tracking_number? = true
        def required_credential_types = %i[api]
        def requirements = %i[credentials]
        def scac = 'TOTL'
        def services = %i[standard]

        def unquotable_accessorials
          %i[
            amusement_park_delivery
            amusement_park_pickup
            athletic_facility_delivery
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
            hospital_delivery
            hospital_pickup
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
            resort_delivery
            resort_pickup
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
          ]
        end

        def unserviceable_accessorials
          %i[
            airport_delivery
            airport_pickup
            appointment_pickup
            brewery_delivery
            brewery_pickup
            convention_delivery
            convention_pickup
            customs_brokerage
            driver_assist
            early_morning_delivery
            fair_delivery
            fair_pickup
            flatbed_delivery
            flatbed_pickup
            grocery_warehouse_delivery
            grocery_warehouse_pickup
            guaranteed_delivery
            guaranteed_delivery_am
            guaranteed_delivery_pm
            military_site_delivery
            military_site_pickup
            winery_delivery
            winery_pickup
          ]
        end
      end

      API = Platforms::CarrierLogistics::API.deep_merge(carrier_code: 'tot').freeze

      # Documents

      # Pickups

      # Rates

      # Tracking

      # protected

      # Documents

      # Rates

      def parse_rate_response(shipment:, response:)
        rate_response = RateResponse.new(request: last_request, response:)

        if response.blank?
          rate_response.error = ResponseError.new('Unknown response')
          return rate_response
        end

        if response.is_a?(String) && response.include?('WebSpeed error')
          rate_response.error = ResponseError.new('API Error: Temporary error (CarrierLogistics WebSpeed error)')
          return rate_response
        end

        error = response.dig('error', 'errormessage')

        if error.present?
          if error.downcase.include?('invalid username/password')
            rate_response.error = InvalidCredentialsError.new
            return rate_response
          end

          if error.downcase.include?('is not available') || error.downcase.include?('out of the serviceable area')
            rate_response.error = UnserviceableError.new
            return rate_response
          end

          rate_response.error = ResponseError.new("API Error: #{error}")
          return rate_response
        end

        if response.dig('ratequote', 'quotetotal').blank?
          rate_response.error = ResponseError.new('Cost is blank')
          return rate_response
        end

        total_cents = parse_amount(response.dig('ratequote', 'quotetotal'))

        transit_days = response.dig('ratequote', 'busdays').to_i
        estimate_reference = response.dig('ratequote', 'quotenumber')

        ratequote_lines = response.dig('ratequote', 'ratequoteline')

        prices = []
        ratequote_lines.each do |ratequote_line|
          next if ratequote_line['chrg'].blank?
          next if ratequote_line['chargedesc'] == 'FREIGHT'

          cents = parse_amount(ratequote_line['chrg'])
          next if cents.zero?

          prices << Price.new(blame: :api, cents:, description: ratequote_line_description(ratequote_line))
        end

        prices = [Price.new(blame: :api, cents: total_cents - prices.sum(&:cents), description: 'Freight')] + prices

        # Carrier-specific pricing structure
        oversized_pallets_cents = 0

        shipment.packages.each do |package|
          short_side, long_side = nil
          if package.length(:in).present? && package.width(:in).present? && package.height(:in).present?
            long_side = [package.length(:in), package.width(:in)].max
            short_side = [package.length(:in), package.width(:in)].min
          end

          next unless short_side &&
                      long_side &&
                      package.height(:in) &&
                      (
                        short_side > 40 ||
                        long_side > 48 ||
                        package.height(:in) > 84
                      )

          oversized_pallets_cents += 1500
        end

        if oversized_pallets_cents.nonzero?
          prices << Price.new(blame: :library, cents: oversized_pallets_cents, description: 'Overlength fees')
        end

        RateResponse.new(
          rates: [
            Rate.new(
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
          ],
          request: last_request,
          response:
        )
      end
    end
  end
end
