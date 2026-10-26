module FreightKit
  module Carriers
    class MegaTransGroup < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '1b130d7a-5f02-4b97-b6c4-687d3494ed7f', phone: '+16304916690')]
        end

        def headquarters
          Address.new(
            city: 'Romeoville',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'f114fa1e-ae32-4f2b-8125-1deccba5e789',
            postal_code: '60446',
            region_abbreviation: 'IL',
            street: '1400 N Independence Blvd'
          )
        end

        def id = '683b2916-b322-4391-8c5a-bddb386b8fe7'
        def legal_name = 'Mega Trans Group LLC'
        def name = 'Mega Trans Group'
        def us_dot_number = 2_996_146
        def website_url = 'https://megatgroup.com'
      end
    end
  end
end
