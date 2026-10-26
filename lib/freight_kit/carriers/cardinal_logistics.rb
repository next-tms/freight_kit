module FreightKit
  module Carriers
    class CardinalLogistics < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '383e233d-73aa-44bd-b4aa-3d59b567839c', phone: '+17862471987')]
        end

        def headquarters
          Address.new(
            city: 'Concord',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '5bcae1a7-cc06-44f6-b31c-2249a52a98e6',
            postal_code: '28027',
            region_abbreviation: 'NC',
            street: '5333 Davidson Highway'
          )
        end

        def id = '0f0ea873-0de4-43d4-a96c-d0cdfeef0be4'
        def legal_name = 'Cardinal Logistics Management Corporation'
        def name = 'Cardinal Logistics'
        def us_dot_number = 191_496
        def us_mc_number = 154_105
      end
    end
  end
end
