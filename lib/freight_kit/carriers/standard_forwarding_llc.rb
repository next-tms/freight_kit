module FreightKit
  module Carriers
    class StandardForwardingLlc < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '0b3cf636-1199-4952-ae0a-5a52c4506d61', phone: '+18004472012')]
        end

        def headquarters
          Address.new(
            city: 'Des Moines',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'b080a9c6-feb0-4491-9c34-23e8667e3e62',
            postal_code: '50316',
            region_abbreviation: 'IA',
            street: '1909 E 17th Street'
          )
        end

        def id = 'f90537f3-f077-4c3a-9701-a1fcbc5a2596'
        def legal_name = 'Standard Forwarding LLC'
        def name = 'Standard Forwarding'
        def scac = 'STDF'
        def us_dot_number = 1_996_747
      end
    end
  end
end
