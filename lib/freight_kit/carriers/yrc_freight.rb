module FreightKit
  module Carriers
    class YRCFreight < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Pasadena',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'b4d30c47-00dc-47b8-a732-29890a6b7032',
              postal_code: '91189',
              region_abbreviation: 'CA',
              street: 'PO Box 100129'
            )
          ]
        end

        def id = '30d0fc37-971b-4a67-bd12-bb4dda3f411a'
        def name = 'YRC Freight'
        def scac = 'RDWY'
      end
    end
  end
end
