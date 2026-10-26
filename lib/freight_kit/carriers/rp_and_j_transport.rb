module FreightKit
  module Carriers
    class RPAndJTransport < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Brawley',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '61c921bd-ac63-443d-ae29-265f47f95a4f',
              postal_code: '92227',
              region_abbreviation: 'CA',
              street: 'PO Box 114'
            )
          ]
        end

        def id = '41da38b1-ca54-4688-b2d5-0f64d028219d'
        def name = 'RP&J Transport'
        def us_mc_number = 1_105_073
      end
    end
  end
end
