module FreightKit
  module Carriers
    class MagicMessenger < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Buena Park',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '080cc465-7820-4d1c-977a-4ba0cfaf4593',
              postal_code: '90621',
              region_abbreviation: 'CA',
              street: '5620 Knott Ave'
            )
          ]
        end

        def id = '3c2b7732-20a5-41a6-99b4-dbf8729929d9'
        def name = 'Magic Messenger'
        def scac = 'MGEG'
      end
    end
  end
end
