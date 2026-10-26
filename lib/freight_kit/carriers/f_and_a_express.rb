module FreightKit
  module Carriers
    class FAndAExpress < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '5c97be59-f5f3-4a03-88a5-4d624e5565b6', phone: '+19567402064')]
        end

        def headquarters
          Address.new(
            city: 'Laredo',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'eee38c99-e888-49e6-95bc-c80b464cb0d6',
            postal_code: '78045',
            region_abbreviation: 'TX',
            street: '1768 FM3338'
          )
        end

        def id = '060d65ae-43ba-4be2-9ff4-c7f2455541ea'
        def legal_name = 'F & A Express LLC'
        def name = 'F&A Express'
        def us_dot_number = 814_450
      end
    end
  end
end
