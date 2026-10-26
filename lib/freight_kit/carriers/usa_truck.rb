module FreightKit
  module Carriers
    class USATruck < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'cee3e38b-1b94-4052-b423-1469827060c6', phone: '+14794310101')]
        end

        def headquarters
          Address.new(
            city: 'Van Buren',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '9d6689f5-bde0-4270-aca2-7e5c91ef6e96',
            postal_code: '72956',
            region_abbreviation: 'AR',
            street: '3200 Industrial Park Road'
          )
        end

        def id = 'f5dcc917-b87c-4416-8a52-33f05d13db45'
        def legal_name = 'USA Truck LLC'
        def name = 'USA Truck'
        def us_dot_number = 213_754
        def website_url = 'https://www.usa-truck.com'
      end
    end
  end
end
