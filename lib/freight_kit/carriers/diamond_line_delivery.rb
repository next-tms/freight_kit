module FreightKit
  module Carriers
    class DiamondLineDelivery < Platforms::CarrierLogistics
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Meridian',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'c91baf64-3416-4c01-9053-b1af899514bb',
              postal_code: '83642',
              region_abbreviation: 'ID',
              street: '1550 S Tech Ln Ste 200'
            )
          ]
        end

        def contacts
          [Contact.new(department: 'Main', id: '373a0d66-6001-41ff-a5a0-542e8b23f9eb', phone: '+12088887133')]
        end

        def headquarters
          Address.new(
            city: 'Meridian',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '85c3f86e-7404-49e2-924c-3438017145b4',
            postal_code: '83642',
            region_abbreviation: 'ID',
            street: '1550 S Tech Ln Ste 200'
          )
        end

        def id = '433c13f7-119e-4e5d-a0e7-b68531ff2e8a'
        def legal_name = 'Diamond Line Delivery Systems Inc'

        # See https://tracking.carrierlogistics.com/scripts/dlds.pol/keywordlist.xml
        def mappable_accessorials
          {
            airport_delivery: 'AIRDEL',
            airport_pickup: 'AIRPIC',
            amusement_park_delivery: 'LIMDEL',
            amusement_park_pickup: 'LIMPIC',
            appointment_pickup: 'NOTIFY',
            athletic_facility_delivery: 'LIMDEL',
            athletic_facility_pickup: 'LIMPIC',
            cemetery_delivery: 'LIMDEL',
            cemetery_pickup: 'LIMPIC',
            church_delivery: 'LIMDEL',
            church_pickup: 'LIMPIC',
            construction_delivery: 'LIMDEL',
            construction_pickup: 'LIMPIC',
            convention_delivery: 'TRADEDEL',
            convention_pickup: 'TRADEPIC',
            farm_delivery: 'LIMDEL',
            farm_pickup: 'LIMPIC',
            fitness_center_delivery: 'LIMDEL',
            fitness_center_pickup: 'LIMPIC',
            golf_course_delivery: 'LIMDEL',
            golf_course_pickup: 'LIMPIC',
            government_delivery: 'LIMDEL',
            government_pickup: 'LIMPIC',
            grocery_store_delivery: 'LIMDEL',
            grocery_store_pickup: 'LIMPIC',
            grocery_warehouse_delivery: 'GROCERYD',
            hospital_delivery: 'LIMDEL',
            hospital_pickup: 'LIMPIC',
            hotel_delivery: 'LIMDEL',
            hotel_pickup: 'LIMPIC',
            inside_delivery: 'INSDEL',
            inside_pickup: 'INSPIC',
            inspection_site_delivery: 'LIMDEL',
            inspection_site_pickup: 'LIMPIC',
            jobsite_delivery: 'LIMDEL',
            jobsite_pickup: 'LIMPIC',
            liftgate_delivery: 'LIFDEL',
            liftgate_pickup: 'LIFPIC',
            mall_delivery: 'LIMDEL',
            mall_pickup: 'LIMPIC',
            marina_delivery: 'LIMDEL',
            marina_pickup: 'LIMPIC',
            military_site_delivery: 'LIMDEL',
            military_site_pickup: 'LIMPIC',
            mine_site_delivery: 'LIMDEL',
            mine_site_pickup: 'LIMPIC',
            mote_delivery: 'LIMDEL',
            motel_pickup: 'LIMPIC',
            nursing_home_delivery: 'LIMDEL',
            nursing_home_pickup: 'LIMPIC',
            park_delivery: 'LIMDEL',
            park_pickup: 'LIMPIC',
            prison_delivery: 'LIMDEL',
            prison_pickup: 'LIMPIC',
            ranch_delivery: 'LIMDEL',
            ranch_pickup: 'LIMPIC',
            reservation_delivery: 'LIMDEL',
            reservation_pickup: 'LIMPIC',
            residential_delivery: 'RESDEL',
            residential_pickup: 'RESPIC',
            resort_delivery: 'LIMDEL',
            resort_pickup: 'LIMPIC',
            restaurant_delivery: 'LIMDEL',
            restaurant_pickup: 'LIMPIC',
            school_delivery: 'LIMDEL',
            school_pickup: 'LIMPIC',
            steel_mill_delivery: 'LIMDEL',
            steel_mill_pickup: 'LIMPIC',
            storage_facility_delivery: 'LIMDEL',
            storage_facility_pickup: 'LIMPIC',
            university_delivery: 'LIMDEL',
            university_pickup: 'LIMPIC',
            utility_site_delivery: 'LIMDEL',
            utility_site_pickup: 'LIMPIC'
          }
        end

        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(8, :feet)
        def name = 'Diamond Line Delivery'
        def overlength_fees_require_tariff? = false
        def scac = 'DLDS'
        def services = %i[standard]
        def unquotable_accessorials = %i[dock_dropoff dock_pickup]

        def unserviceable_accessorials
          %i[
            brewery_delivery
            brewery_pickup
            customs_brokerage
            driver_assist
            early_morning_delivery
            fair_delivery
            fair_pickup
            flatbed_delivery
            flatbed_pickup
            grocery_warehouse_pickup
            guaranteed_delivery
            guaranteed_delivery_am
            guaranteed_delivery_pm
            winery_delivery
            winery_pickup
          ]
        end

        def us_dot_number = 887_550
        def us_mc_number = 386_888
      end

      API = Platforms::CarrierLogistics::API.deep_merge(
        domain: 'tracking.carrierlogistics.com',
        endpoints: { rates: '/scripts/dlds.pol/ratequote.xml?' },
        use_ssl: { rates: true }
      ).freeze

      # Documents

      # Rates
      def build_calculated_accessorials(shipment)
        [].tap do |builder|
          builder << 'SS'
          builder << 'HAZ' if shipment.packages.any?(&:hazmat?)
        end
      end

      # Tracking

      # protected

      # Documents

      # Rates
    end
  end
end
