module FreightKit
  module Carriers
    class ShawneeTrucking < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'cc54bc7b-4053-4d10-9a79-c05e5c06fd99', phone: '+12014387060')]
        end

        def headquarters
          Address.new(
            city: 'Clifton',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '00527f54-15cb-49c4-a1b4-e4c04b041824',
            postal_code: '07012',
            region_abbreviation: 'NJ',
            street: '50 Somerset Place'
          )
        end

        def id = 'f619ca2e-b7ec-4a3a-a190-e970c135ba44'
        def legal_name = 'Shawnee Trucking Company Inc'
        def name = 'Shawnee Trucking'
        def us_dot_number = 564_981
        def us_mc_number = 275_313
      end
    end
  end
end
