module FreightKit
  module Carriers
    class WardTrucking < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '2acc9195-e293-4ad1-9a54-adf666a4f7ba', phone: '+18149440803')]
        end

        def headquarters
          Address.new(
            city: 'Altoona',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'a6bfa4bc-9972-4124-a3f8-cf8eeb051ce4',
            postal_code: '16602',
            region_abbreviation: 'PA',
            street: '1436 Ward Trucking Drive'
          )
        end

        def id = '028f9937-c629-4e55-9339-957e79049c8e'
        def legal_name = 'Ward Trucking LLC'
        def name = 'Ward Trucking'
        def scac = 'WARD'
        def us_dot_number = 84_850
        def us_mc_number = 65_916
      end
    end
  end
end
