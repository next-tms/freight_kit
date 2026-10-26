module FreightKit
  module Carriers
    class WinDistribution < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '65927550-1747-4a2b-b880-4e5fbd5fccf2', phone: '+17027337050')]
        end

        def headquarters
          Address.new(
            city: 'Las Vegas',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'c1ad37f6-54cd-4855-b77d-8d67bb931838',
            postal_code: '89139',
            region_abbreviation: 'NV',
            street: '9575 Redwood Street'
          )
        end

        def id = 'f5b2e59f-4e29-4e72-ba67-c185f259bc29'
        def legal_name = 'Its Trucking And Warehousing LLC'
        def name = 'Win Distribution'
        def us_dot_number = 2_165_868
        def us_mc_number = 752_507
      end
    end
  end
end
