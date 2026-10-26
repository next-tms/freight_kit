module FreightKit
  module Carriers
    class QueenStarTrucking < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '41778739-dc62-429f-8499-01809bb0bb39', phone: '+16266522981')]
        end

        def headquarters
          Address.new(
            city: 'Rancho Cucamonga',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '5c6fe691-406b-4612-9531-8c45c31e5f92',
            postal_code: '91739',
            region_abbreviation: 'CA',
            street: '8225 Sunset Hills Pl'
          )
        end

        def id = '3e50c231-d410-47f7-80d9-0aefe364fdd2'
        def legal_name = 'Queen Star Trucking Inc'
        def name = 'Queen Star Trucking'
        def us_dot_number = 1_990_904
      end
    end
  end
end
