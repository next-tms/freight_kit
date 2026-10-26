module FreightKit
  module Carriers
    class XpressGlobalSystems < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '72b8ba38-1281-47d1-86e1-2f6c9df102d9', phone: '+17063413393')]
        end

        def headquarters
          Address.new(
            city: 'Tunnel Hill',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '093e63fd-0d3d-4730-8386-e4e789a376b0',
            postal_code: '30755',
            region_abbreviation: 'GA',
            street: '1537 New Hope Church Road'
          )
        end

        def id = '1802a2a1-a0f8-4a8b-a441-acc40a8f18e0'
        def legal_name = 'Xpress Global Systems LLC'
        def name = 'Xpress Global Systems'
        def scac = 'XGSI'
        def us_dot_number = 534_817
        def us_mc_number = 188_471
        def website_url = 'https://www.xgsi.com'
      end
    end
  end
end
