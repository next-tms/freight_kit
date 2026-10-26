module FreightKit
  module Carriers
    class TSIKansas < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'fb808a4c-fac6-4839-a564-3aa1ea6317a1', phone: '+17856325183')]
        end

        def headquarters
          Address.new(
            city: 'Clay Center',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '451c80fa-739b-489c-b7dd-bc69997c7340',
            postal_code: '67432-2313',
            region_abbreviation: 'KS',
            street: '612 West Court Street'
          )
        end

        def id = '4d0b9c09-4be7-42c3-884c-6e5aecd88423'
        def legal_name = 'TSI Kansas Inc'
        def name = 'TSI Kansas'
        def us_dot_number = 1_083_594
        def us_mc_number = 423_946
        def website_url = 'https://tsikansas.com'
      end
    end
  end
end
