module FreightKit
  module Carriers
    class Landstar < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Philadelphia',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '19f2841c-dc90-4a72-8d80-580ed1dc640e',
              postal_code: '19178',
              region_abbreviation: 'PA',
              street: 'PO Box 784293'
            )
          ]
        end

        def id = '464c3dc6-d1a2-4429-b531-d10ea0b81b0c'
        def name = 'Landstar'
        def scac = 'LAND'
        def website_url = 'https://www.landstar.com'
      end
    end
  end
end
