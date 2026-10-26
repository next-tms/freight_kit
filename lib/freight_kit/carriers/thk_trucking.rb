module FreightKit
  module Carriers
    class THKTrucking < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '0d6cf829-3835-42ad-859b-0852b1ed5fd2', phone: '+16308782993')]
        end

        def headquarters
          Address.new(
            city: 'Elmhurst',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '4c405b47-1325-45d7-80df-3a541978e3ac',
            postal_code: '60126',
            region_abbreviation: 'IL',
            street: '562 West Lorraine Ave'
          )
        end

        def id = '630f9d07-6ba2-4fb6-857f-e48379c08b4c'
        def legal_name = 'THK Trucking Inc'
        def name = 'THK Trucking'
        def us_dot_number = 1_526_463
        def us_mc_number = 593_205
      end
    end
  end
end
