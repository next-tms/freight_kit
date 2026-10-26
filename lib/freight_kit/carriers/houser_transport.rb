module FreightKit
  module Carriers
    class HouserTransport < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '156ed19f-4ad9-4aaa-b102-e191cbae3d31', phone: '+12143049001')]
        end

        def headquarters
          Address.new(
            city: 'Royse City',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '90e022cb-a0df-4b39-82a2-492f8d1cee28',
            postal_code: '75189',
            region_abbreviation: 'TX',
            street: '2201 E State Highway 66'
          )
        end

        def id = 'f7f29f63-a09e-47a3-8508-ce274e5df5bc'
        def legal_name = 'Houser Transport LLC'
        def name = 'Houser Transport'
        def us_dot_number = 3_452_785
      end
    end
  end
end
