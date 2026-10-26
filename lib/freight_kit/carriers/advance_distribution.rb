module FreightKit
  module Carriers
    class AdvanceDistribution < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '38161452-94fe-4f2c-ab22-557ff44d0c4a', phone: '+17655535999')]
        end

        def headquarters
          Address.new(
            city: 'Kokomo',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '6a11b04d-514e-47df-821c-069b57748272',
            postal_code: '46901',
            region_abbreviation: 'IN',
            street: '700 Touby Pike'
          )
        end

        def id = '0cece448-c35a-40d5-9f40-08de623f808b'
        def legal_name = 'Advance Distribution Inc'
        def name = 'Advance Distribution'
        def us_dot_number = 709_610
        def website_url = 'https://shipadi.com'
      end
    end
  end
end
