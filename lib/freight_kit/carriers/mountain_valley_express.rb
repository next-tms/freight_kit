module FreightKit
  module Carriers
    class MountainValleyExpress < Platforms::CarrierLogistics
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Jurupa Valley',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'c6e8a2a5-29fd-4c64-99a3-cef20f20cd37',
              postal_code: '91752',
              region_abbreviation: 'CA',
              street: '4685 Pier Enterprises Way Ste B'
            )
          ]
        end

        def contacts
          [Contact.new(department: 'Main', id: 'c61f7a37-dee6-4e68-8240-404a30a6c495', phone: '+18773256447')]
        end

        def headquarters
          Address.new(
            city: 'Manteca',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'd62512bc-08f5-4539-890e-e965909058bb',
            postal_code: '95337',
            region_abbreviation: 'CA',
            street: '1019 Bessemer Ave'
          )
        end

        def id = 'ff9e9eeb-7fe8-4307-b3bd-7ddd6e76b6ab'
        def legal_name = 'Mountain Valley Express LLC'

        def mappable_accessorials
          {
            amusement_park_delivery: 'LTDD',
            amusement_park_pickup: 'LTDP',
            appointment_delivery: 'APPT',
            athletic_facility_delivery: 'LTDD',
            athletic_facility_pickup: 'LTDP',
            cemetery_delivery: 'LTDD',
            cemetery_pickup: 'LTDP',
            church_delivery: 'LTDD',
            church_pickup: 'LTDP',
            construction_delivery: 'COND',
            construction_pickup: 'CONP',
            dock_dropoff: 'LTDD',
            dock_pickup: 'LTDP',
            farm_delivery: 'LTDD',
            farm_pickup: 'LTDP',
            fitness_center_delivery: 'LTDD',
            fitness_center_pickup: 'LTDP',
            golf_course_delivery: 'LTDD',
            golf_course_pickup: 'LTDP',
            government_delivery: 'LTDD',
            government_pickup: 'LTDP',
            grocery_store_delivery: 'LTDP',
            grocery_store_pickup: 'LTDP',
            grocery_warehouse_delivery: 'GROC',
            grocery_warehouse_pickup: 'LTDP',
            hospital_delivery: 'LTDD',
            hospital_pickup: 'LTDP',
            hotel_delivery: 'LTDD',
            hotel_pickup: 'LTDP',
            inside_delivery: 'INSD',
            inside_pickup: 'INSP',
            inspection_site_delivery: 'LTDD',
            inspection_site_pickup: 'LTDP',
            jobsite_delivery: 'LTDD',
            jobsite_pickup: 'LTDP',
            liftgate_delivery: 'LIFD',
            liftgate_pickup: 'LIFP',
            mall_delivery: 'LTDD',
            mall_pickup: 'LTDP',
            marina_delivery: 'LTDD',
            marina_pickup: 'LTDP',
            military_site_delivery: 'LTDD',
            military_site_pickup: 'LTDP',
            mine_site_delivery: 'MINED',
            mine_site_pickup: 'MINEP',
            motel_delivery: 'LTDD',
            motel_pickup: 'LTDP',
            nursing_home_delivery: 'LTDD',
            nursing_home_pickup: 'LTDP',
            park_delivery: 'LTDD',
            park_pickup: 'LTDP',
            prison_delivery: 'LTDD',
            prison_pickup: 'LTDP',
            ranch_delivery: 'LTDD',
            ranch_pickup: 'LTDP',
            reservation_delivery: 'LTDD',
            reservation_pickup: 'LTDP',
            residential_delivery: 'RESI',
            residential_pickup: 'RESP',
            resort_delivery: 'LTDD',
            resort_pickup: 'LTDP',
            restaurant_delivery: 'LTDD',
            restaurant_pickup: 'LTDP',
            school_delivery: 'LTDD',
            school_pickup: 'LTDP',
            steel_mill_delivery: 'LTDD',
            steel_mill_pickup: 'LTDP',
            storage_facility_delivery: 'LTDD',
            storage_facility_pickup: 'LTDP',
            university_delivery: 'LTDD',
            university_pickup: 'LTDP',
            utility_site_delivery: 'LTDD',
            utility_site_pickup: 'LTDP'
          }
        end

        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(12, :feet)
        def name = 'Mountain Valley Express'
        def overlength_fees_require_tariff? = false
        def scac = 'DCHA'
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
            winery_delivery
            winery_pickup
          ]
        end

        def us_dot_number = 172_279
      end

      API = Platforms::CarrierLogistics::API.deep_merge(carrier_code: 'dcha').freeze

      # Documents

      # Rates
      def build_calculated_accessorials(shipment)
        [].tap do |builder|
          builder << 'HAZM' if shipment.packages.any?(&:hazmat?)

          if shipment.accessorials.present? && %i[
            residential_delivery
            residential_pickup
          ].intersect?(shipment.accessorials)
            builder << 'RES'
          end

          longest_dimension = shipment.packages.map { |package| [package.length(:in), package.width(:in)].max }.max.ceil

          case longest_dimension
          when (144..155) then builder << 'XL12'
          when (156..167) then builder << 'XL13'
          when (168..179) then builder << 'XL14'
          when (180..191) then builder << 'XL15'
          when (192..203) then builder << 'XL16'
          when (204..215) then builder << 'XL17'
          when (216..227) then builder << 'XL18'
          when (228..239) then builder << 'XL19'
          when (240..251) then builder << 'XL20'
          when (252..483) then builder << 'XL21'
          when (484..275) then builder << 'XL22'
          when (276..287) then builder << 'XL23'
          when (288..299) then builder << 'XL24'
          when (300..311) then builder << 'XL25'
          when (312..323) then builder << 'XL26'
          when (324..) then builder << 'XL27'
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
