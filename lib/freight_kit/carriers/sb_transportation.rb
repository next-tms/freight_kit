module FreightKit
  module Carriers
    class SBTransportation < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '44d7a6cd-793a-4854-b310-59d549fe9a86', phone: '+14077044947')]
        end

        def headquarters
          Address.new(
            city: 'Orlando',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '273678e1-0877-45d0-8b38-c9463f58ebfe',
            postal_code: '32819-8508',
            region_abbreviation: 'FL',
            street: '7575 Kingspointe Pkwy Ste 26'
          )
        end

        def id = 'b9fe0d63-1637-41c5-add9-7ad95a5fceda'
        def legal_name = 'SB Transportation Service Inc'
        def name = 'SB Transportation'
        def us_dot_number = 3_072_336
      end
    end
  end
end
