module FreightKit
  module Carriers
    class NewCenturyTransport < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'e5abdf2f-f825-48df-955d-e28f9b9b776f', phone: '+18006081840')]
        end

        def headquarters
          Address.new(
            city: 'Sumner',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '7259f3ae-f95f-446c-bc46-e18ceddee5fc',
            postal_code: '98390',
            region_abbreviation: 'WA',
            street: '1812 136th Ave E'
          )
        end

        def id = '68c1581a-17eb-4395-870e-733b806e043a'
        def legal_name = 'New Century Transport LLC'
        def name = 'New Century Transport'
        def us_dot_number = 1_543_578
        def us_mc_number = 574_047
      end
    end
  end
end
