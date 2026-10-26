module FreightKit
  module Carriers
    class PiousTrans < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '79e59fa4-f4a9-4153-a01a-d0d5ef887324', phone: '+13176660090')]
        end

        def headquarters
          Address.new(
            city: 'Greenwood',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '53f399c5-605b-4c44-b95e-1674f7ca8c2a',
            postal_code: '46143',
            region_abbreviation: 'IN',
            street: '160 Imel Way'
          )
        end

        def id = 'f96ce51a-53ac-4ce2-9fb8-37e115e03030'
        def legal_name = 'Pious Trans Inc'
        def name = 'Pious Trans'
        def us_dot_number = 3_113_715
      end
    end
  end
end
