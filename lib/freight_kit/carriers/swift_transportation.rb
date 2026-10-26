module FreightKit
  module Carriers
    class SwiftTransportation < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'f1667bb3-eff1-46ba-a229-75680caa82de', phone: '+18008002200')]
        end

        def headquarters
          Address.new(
            city: 'Phoenix',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '8eed48af-d87a-4a90-8a4b-2bb1d0cd75d2',
            postal_code: '85043',
            region_abbreviation: 'AZ',
            street: '2200 S 75th Ave'
          )
        end

        def id = 'c89e61f3-16ee-4e37-8c55-296e65611d71'
        def legal_name = 'Swift Transportation Company Of Arizona LLC'
        def name = 'Swift Transportation'
        def us_dot_number = 54_283
        def us_mc_number = 136_818
      end
    end
  end
end
