module FreightKit
  module Carriers
    class FedExExpress < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '625da356-413c-4df7-94e1-84d00bc7e5ea', phone: '+14127478482')]
        end

        def headquarters
          Address.new(
            city: 'Memphis',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '478a040f-e994-4d27-b70c-873d38d2b5c4',
            postal_code: '38125',
            region_abbreviation: 'TN',
            street: '3660 Hacks Cross Rd Bldg F 2nd Fl'
          )
        end

        def id = '1b368f49-dd1f-4a56-8f4a-f695299d3a94'
        def legal_name = 'Federal Express Corporation'
        def name = 'FedEx Express'
        def scac = 'FDEN'
        def us_dot_number = 86_876
        def us_mc_number = 66_562
        def website_url = 'https://www.fedex.com'
      end
    end
  end
end
