module FreightKit
  module Carriers
    class OrangeCourier < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'd16cc0ef-7ed6-4fc9-8b24-c33809817689', phone: '+17143843600')]
        end

        def headquarters
          Address.new(
            city: 'La Mirada',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '31fede2a-9a5f-4f20-93d1-3b7618c82aa9',
            postal_code: '90638',
            region_abbreviation: 'CA',
            street: '15300 Desman Rd'
          )
        end

        def id = '25cd5d4c-fde5-4dad-8a4b-f69ea7cbd82a'
        def legal_name = 'Orange Courier Inc'
        def name = 'Orange Courier'
        def us_dot_number = 710_576
      end
    end
  end
end
