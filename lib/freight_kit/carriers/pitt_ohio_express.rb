module FreightKit
  module Carriers
    class PittOhioExpress < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'b589263b-0103-4aca-a674-c999545bbc76', phone: '+14122323015')]
        end

        def headquarters
          Address.new(
            city: 'Pittsburgh',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'fba7446a-faa1-4b57-b174-9c772b85cefd',
            postal_code: '15222',
            region_abbreviation: 'PA',
            street: '15 27th Street'
          )
        end

        def id = '30c9de89-a48e-4078-87f1-64ad1572002e'
        def legal_name = 'Pitt Ohio Express LLC'
        def name = 'Pitt Ohio Express'
        def scac = 'PITD'
        def us_dot_number = 190_180
        def us_mc_number = 30_136
        def website_url = 'https://pittohio.com'
      end
    end
  end
end
