module FreightKit
  module Carriers
    class ProTransSolutions < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'a52713b6-7826-4c7d-9ea4-bb85c833ec14', phone: '+18553553332')]
        end

        def headquarters
          Address.new(
            city: 'Romeoville',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '46ba5377-9782-4d48-8c5b-e1f205a4eaa0',
            postal_code: '60446',
            region_abbreviation: 'IL',
            street: '420 Gainsborough Dr'
          )
        end

        def id = 'e9820192-d977-45a2-a926-ad4ced570bdc'
        def legal_name = 'Pro-trans Solutions LLC'
        def name = 'Pro Trans Solutions'
        def us_dot_number = 1_547_614
        def us_mc_number = 586_092
      end
    end
  end
end
