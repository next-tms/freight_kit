module FreightKit
  module Carriers
    class OakHarbor < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'f40d6627-d49d-4bab-b1b6-c4540150a160', phone: '+12062462600')]
        end

        def headquarters
          Address.new(
            city: 'Auburn',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'c135e3cd-1c03-4de4-b138-35dd343d220b',
            postal_code: '98001',
            region_abbreviation: 'WA',
            street: '1339 West Valley Hwy North'
          )
        end

        def id = '98c05d2a-daab-46df-b627-2c326096117e'
        def legal_name = 'Oak Harbor Freight Lines Inc'
        def name = 'Oak Harbor'
        def us_dot_number = 8_314
        def us_mc_number = 139_763
      end
    end
  end
end
