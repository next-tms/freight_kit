module FreightKit
  module Carriers
    class MotoTransportation < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Surrey',
              country: Countries.find_by(iso31661_alpha2: 'CA'),
              id: 'e186dd4a-f95e-49b8-afaf-3d03a7976714',
              postal_code: 'V3S 9S4',
              region_abbreviation: 'BC',
              street: '155 176th St Unit 206'
            )
          ]
        end

        def id = '88313e36-bfb2-40ed-bd0f-eeb3a44b371d'
        def name = 'Moto Transportation'
        def scac = 'MTVW'
      end
    end
  end
end
