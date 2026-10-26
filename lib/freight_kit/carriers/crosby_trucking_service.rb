module FreightKit
  module Carriers
    class CrosbyTruckingService < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '8f0e96f7-c0e8-409a-8773-e1886abaf296', phone: '+15402349268')]
        end

        def headquarters
          Address.new(
            city: 'Mt Sidney',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'b6aa80c9-3fab-4097-ba56-be53c22916b6',
            postal_code: '24467',
            region_abbreviation: 'VA',
            street: '270 Keezletown Road'
          )
        end

        def id = '52ef5a35-0c6b-4a70-a3ac-4568f273d859'
        def legal_name = 'Crosby Trucking Service Inc'
        def name = 'Crosby Trucking Service'
        def us_dot_number = 32_052
        def us_mc_number = 142_823
        def website_url = 'https://www.crosbytrucking.com'
      end
    end
  end
end
