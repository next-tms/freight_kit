module FreightKit
  module Carriers
    class UAndRTransportation < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Olympia',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '2251b5b5-76ac-4a6d-bf84-072a3326dc1e',
              postal_code: '98508',
              region_abbreviation: 'WA',
              street: 'PO Box 11099'
            )
          ]
        end

        def id = '0c4efb88-bc6f-4777-a8ca-4b2419af4cac'
        def name = 'U&R Transportation'
      end
    end
  end
end
