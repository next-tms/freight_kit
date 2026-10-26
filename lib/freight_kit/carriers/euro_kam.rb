module FreightKit
  module Carriers
    class EuroKam < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'd129bdb5-5e6c-45d5-97b6-d4a4a0eae02e', phone: '+18474500046')]
        end

        def headquarters
          Address.new(
            city: 'Bensenville',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '2effc808-c418-4ec8-8aca-859b79d6b59a',
            postal_code: '60106',
            region_abbreviation: 'IL',
            street: '1101 Irving Park Rd Unit 200'
          )
        end

        def id = '757eaa8c-b6d8-4e03-9a79-c2a7eb60ff7f'
        def legal_name = 'Euro Kam Ltd'
        def name = 'Euro Kam'
        def us_dot_number = 1_330_926
        def website_url = 'https://eurokamcorp.com'
      end
    end
  end
end
