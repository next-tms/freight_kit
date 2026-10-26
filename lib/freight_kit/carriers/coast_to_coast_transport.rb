module FreightKit
  module Carriers
    class CoastToCoastTransport < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '1f791e8b-74cb-452d-971b-50b37f0dac2e', phone: '+13363624940')]
        end

        def headquarters
          Address.new(
            city: 'Salisbury',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '949745f1-ec5c-4955-b384-60ecc1ff8c4d',
            postal_code: '28146',
            region_abbreviation: 'NC',
            street: '324 Sailboat Dr'
          )
        end

        def id = '760faad0-3911-4dc5-bf8e-f8a6e697dc06'
        def legal_name = 'Coast to Coast Transport LLC'
        def name = 'Coast to Coast Transport'
        def us_dot_number = 3_157_546
      end
    end
  end
end
