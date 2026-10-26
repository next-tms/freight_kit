module FreightKit
  module Carriers
    class AmericanFastFreight < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '98fba1b3-c631-46da-bfb3-9a1d6d1b36ef', phone: '+12538886392')]
        end

        def headquarters
          Address.new(
            city: 'Fife',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '555d5c3d-411d-4c66-8025-10b09ac305f8',
            postal_code: '98424',
            region_abbreviation: 'WA',
            street: '7400 45th St Ct E'
          )
        end

        def id = '0cf1b30b-d564-4cf0-a11c-e1abac432c8a'
        def legal_name = 'American Fast Freight Inc'
        def name = 'American Fast Freight'
        def us_dot_number = 340_754
        def us_mc_number = 207_555
      end
    end
  end
end
