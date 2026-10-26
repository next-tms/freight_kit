module FreightKit
  module Carriers
    class ADuiePyle < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '07dd8d84-72ad-4615-bed5-b0a1b5a3c9dc', phone: '+16106965800')]
        end

        def headquarters
          Address.new(
            city: 'West Chester',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '1567bf10-dcb8-4eae-9bbb-d211c2ab3810',
            postal_code: '19382',
            region_abbreviation: 'PA',
            street: '650 Westtown Rd'
          )
        end

        def id = '57593449-77b3-4966-beca-4ab37fd3a927'
        def legal_name = 'A Duie Pyle Inc'
        def name = 'A Duie Pyle'
        def scac = 'PYLE'
        def us_dot_number = 113_594
        def us_mc_number = 39_140
        def website_url = 'https://aduiepyle.com'
      end
    end
  end
end
