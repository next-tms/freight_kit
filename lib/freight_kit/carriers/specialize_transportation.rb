module FreightKit
  module Carriers
    class SpecializeTransportation < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '8e654b05-ef77-457a-9110-b66040afee49', phone: '+17709676331')]
        end

        def headquarters
          Address.new(
            city: 'Braselton',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '65b2521f-619f-44dd-bcbb-ed4f5396f90c',
            postal_code: '30517',
            region_abbreviation: 'GA',
            street: '5475 Technology Pkwy'
          )
        end

        def id = '0bc499e6-6c9c-42e3-abfc-89e3466667a3'
        def legal_name = 'Specialize Transportation Inc'
        def name = 'Specialize Transportation'
        def us_dot_number = 516_204
      end
    end
  end
end
