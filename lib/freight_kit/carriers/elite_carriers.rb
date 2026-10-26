module FreightKit
  module Carriers
    class EliteCarriers < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '82e44ccd-e5cb-4ff5-b13c-023bd41f42cc', phone: '+17155365454')]
        end

        def headquarters
          Address.new(
            city: 'Merrill',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '765ab28e-9e16-4057-b428-e77ebe9f8575',
            postal_code: '54452',
            region_abbreviation: 'WI',
            street: 'N1545 County Rd W'
          )
        end

        def id = '93983016-03e8-4292-8716-e34d29e74ecf'
        def legal_name = 'Elite Carriers LLC'
        def name = 'Elite Carriers'
        def us_dot_number = 589_271
        def us_mc_number = 286_746
      end
    end
  end
end
