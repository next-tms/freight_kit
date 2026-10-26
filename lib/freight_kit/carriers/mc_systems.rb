module FreightKit
  module Carriers
    class MCSystems < Carrier
      class << self
        def contacts
          [
            Contact.new(
              department: 'Main',
              email: 'dispatch@mcs-transport.com',
              id: 'fd2ab7cf-6928-4d9c-b25f-d56c63dc8dc4',
              phone: '+13173481914'
            )
          ]
        end

        def headquarters
          Address.new(
            city: 'Compton',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '8029826b-e4df-49bd-b2a2-efa1d6621c23',
            postal_code: '90220',
            region_abbreviation: 'CA',
            street: '355 W Carob St'
          )
        end

        def id = '02f1233a-59d7-4ffd-90ef-2d747a448333'
        def legal_name = 'MC Systems Inc'
        def name = 'MC Systems'
        def us_dot_number = 1_660_193
        def website_url = 'https://www.mcs-transport.com'
      end
    end
  end
end
