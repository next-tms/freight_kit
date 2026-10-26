module FreightKit
  module Carriers
    class InfinitiFreightLogistics < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '097932de-b5f6-404c-89d2-a6a79c7a8cc4', phone: '+18185769913')]
        end

        def headquarters
          Address.new(
            city: 'Northridge',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'c6bfe6c3-72d4-4ffd-8e58-d402b1affd0a',
            postal_code: '91324',
            region_abbreviation: 'CA',
            street: '9045 Corbin Ave Suite # B2'
          )
        end

        def id = '1421d83b-5e64-4c4c-8fa1-b4d1f2e511a3'
        def legal_name = 'Infiniti Freight Logistics Inc'
        def name = 'Infiniti Freight Logistics'
        def us_dot_number = 2_006_571
        def us_mc_number = 707_774
      end
    end
  end
end
