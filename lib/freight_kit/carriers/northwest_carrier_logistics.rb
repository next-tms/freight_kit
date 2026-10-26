module FreightKit
  module Carriers
    class NorthwestCarrierLogistics < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '9effbbda-8003-4680-a310-14d4e4932863', phone: '+13605107784')]
        end

        def headquarters
          Address.new(
            city: 'Blaine',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'dbecffeb-fae0-42af-82ad-f93f05f6c00f',
            postal_code: '98230',
            region_abbreviation: 'WA',
            street: '8282 Portal Way'
          )
        end

        def id = 'c11303c6-1dff-4d8c-a08d-aaf2ee6b6da0'
        def legal_name = 'Northwest Carrier Logistics LLC'
        def name = 'Northwest Carrier Logistics'
        def us_dot_number = 1_202_098
      end
    end
  end
end
