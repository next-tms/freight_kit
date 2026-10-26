module FreightKit
  module Carriers
    class PlanaTransportation < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '170285fc-9218-4e2a-86e5-9e5f8bbf249b', phone: '+16308607119')]
        end

        def headquarters
          Address.new(
            city: 'Wood Dale',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '72c83732-7da3-45c5-9c0a-6a0e30da1187',
            postal_code: '60191',
            region_abbreviation: 'IL',
            street: '655 North Central Ave Unit E'
          )
        end

        def id = 'd42a1e84-dff1-4dc6-8fa7-b2057fd9ea5b'
        def legal_name = 'Plana Transportation Inc'
        def name = 'Plana Transportation'
        def us_dot_number = 1_891_990
        def us_mc_number = 681_072
      end
    end
  end
end
