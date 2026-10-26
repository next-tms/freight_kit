module FreightKit
  module Carriers
    class MorganVanLines < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'f9f26d54-3905-48bb-b481-0652c02ce481', phone: '+16627282221')]
        end

        def headquarters
          Address.new(
            city: 'Booneville',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'ff77328e-552c-4936-a640-753606ea5031',
            postal_code: '38829',
            region_abbreviation: 'MS',
            street: '2719 South Second Street'
          )
        end

        def id = '0f7bdceb-8f5f-4fbe-9645-d084c8f40f5f'
        def legal_name = 'Morgan Van Lines Inc'
        def name = 'Morgan Van Lines'
        def us_dot_number = 151_057
        def us_mc_number = 144_474
        def website_url = 'https://www.mvlonline.com'
      end
    end
  end
end
