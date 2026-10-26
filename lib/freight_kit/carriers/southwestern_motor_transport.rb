module FreightKit
  module Carriers
    class SouthwesternMotorTransport < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '1c08f628-6d56-41d9-b381-4feedfc6cab8', phone: '+12106616791')]
        end

        def headquarters
          Address.new(
            city: 'San Antonio',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '09fe17b4-8d19-4501-8455-4b31c9460705',
            postal_code: '78218',
            region_abbreviation: 'TX',
            street: '4600 Goldfield'
          )
        end

        def id = 'f45ef864-e505-4946-8676-a49b961be91d'
        def legal_name = 'Southwestern Motor Transport Inc'
        def name = 'Southwestern Motor Transport'
        def scac = 'SMTL'
        def us_dot_number = 136_555
        def us_mc_number = 825_355
        def website_url = 'https://www.smtl.com'
      end
    end
  end
end
