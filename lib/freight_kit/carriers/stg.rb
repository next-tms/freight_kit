module FreightKit
  module Carriers
    class STG < Platforms::CarrierLogistics
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Walnut',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '0d8533a9-f096-456d-905b-38b509f6b06d',
              postal_code: '91789',
              region_abbreviation: 'CA',
              street: '20405 Business Parkway'
            )
          ]
        end

        def id = '27e76a5e-0281-4b7e-8473-188de9159ab5'

        def mappable_accessorials
          {
            amusement_park_delivery: 'NONCOMM',
            amusement_park_pickup: 'NONCMPU',
            appointment_delivery: 'NOT',
            athletic_facility_delivery: 'NONCOMM',
            athletic_facility_pickup: 'NONCMPU',
            cemetery_delivery: 'NONCOMM',
            cemetery_pickup: 'NONCMPU',
            church_delivery: 'NONCOMM',
            church_pickup: 'NONCMPU',
            construction_delivery: 'NONCOMM',
            construction_pickup: 'NONCMPU',
            dock_dropoff: 'NONCOMM',
            dock_pickup: 'NONCMPU',
            farm_delivery: 'NONCOMM',
            farm_pickup: 'NONCMPU',
            fitness_center_delivery: 'NONCOMM',
            fitness_center_pickup: 'NONCMPU',
            golf_course_delivery: 'NONCOMM',
            golf_course_pickup: 'NONCMPU',
            government_delivery: 'NONCOMM',
            government_pickup: 'NONCMPU',
            grocery_store_delivery: 'NONCMPU',
            grocery_store_pickup: 'NONCMPU',
            grocery_warehouse_delivery: 'GROC',
            grocery_warehouse_pickup: 'NONCMPU',
            hospital_delivery: 'NONCOMM',
            hospital_pickup: 'NONCMPU',
            hotel_delivery: 'NONCOMM',
            hotel_pickup: 'NONCMPU',
            inspection_site_delivery: 'NONCOMM',
            inspection_site_pickup: 'NONCMPU',
            jobsite_delivery: 'NONCOMM',
            jobsite_pickup: 'NONCMPU',
            liftgate_delivery: 'LIFTGATE',
            liftgate_pickup: 'LIFTPU',
            mall_delivery: 'NONCOMM',
            mall_pickup: 'NONCMPU',
            marina_delivery: 'NONCOMM',
            marina_pickup: 'NONCMPU',
            military_site_delivery: 'NONCOMM',
            military_site_pickup: 'NONCMPU',
            mine_site_delivery: 'NONCOMM',
            mine_site_pickup: 'NONCMPU',
            motel_delivery: 'NONCOMM',
            motel_pickup: 'NONCMPU',
            nursing_home_delivery: 'NONCOMM',
            nursing_home_pickup: 'NONCMPU',
            park_delivery: 'NONCOMM',
            park_pickup: 'NONCMPU',
            prison_delivery: 'NONCOMM',
            prison_pickup: 'NONCMPU',
            ranch_delivery: 'NONCOMM',
            ranch_pickup: 'NONCMPU',
            reservation_delivery: 'NONCOMM',
            reservation_pickup: 'NONCMPU',
            residential_delivery: 'RESIDENT',
            residential_pickup: 'NONCMPU',
            resort_delivery: 'NONCOMM',
            resort_pickup: 'NONCMPU',
            restaurant_delivery: 'NONCOMM',
            restaurant_pickup: 'NONCMPU',
            school_delivery: 'NONCOMM',
            school_pickup: 'NONCMPU',
            steel_mill_delivery: 'NONCOMM',
            steel_mill_pickup: 'NONCMPU',
            storage_facility_delivery: 'NONCOMM',
            storage_facility_pickup: 'NONCMPU',
            university_delivery: 'NONCOMM',
            university_pickup: 'NONCMPU',
            utility_site_delivery: 'NONCOMM',
            utility_site_pickup: 'NONCMPU'
          }
        end

        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(12, :feet)
        def name = 'STG'
        def overlength_fees_require_tariff? = false
        def rates_with_excessive_length_fees? = false
        def scac = 'FCSY'
        def services = %i[standard]

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
            guaranteed_delivery
            guaranteed_delivery_am
            guaranteed_delivery_pm
            inside_delivery
            inside_pickup
            winery_delivery
            winery_pickup
          ]
        end
      end

      API = Platforms::CarrierLogistics::API.deep_merge(carrier_code: 'fro').freeze

      # Documents

      # Rates

      def build_calculated_accessorials(shipment)
        [].tap do |builder|
          builder << 'AMAZON' if AmazonWarehouse.include?(shipment.destination)

          longest_dimension = shipment.packages.map { |package| [package.length(:in), package.width(:in)].max }.max.ceil

          case longest_dimension
          when (96..143) then builder << 'XTRM8'
          when (144..191) then builder << 'XTRM12'
          when (192..239) then builder << 'XTRM16'
          when (240..311) then builder << 'XTRM20'
          when (312..) then builder << 'XTRM27'
          end
        end
      end

      # Tracking

      # protected

      # Documents

      # Rates
    end
  end
end
