module FreightKit
  module Carriers
    class GSPExpress < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Madison',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'db94ccc5-6085-4236-870e-c3af8ca91c52',
              postal_code: '57042',
              region_abbreviation: 'SD',
              street: 'PO Box 347'
            )
          ]
        end

        def id = '42b3f8f9-c85c-4144-b2e3-172386bc29d4'
        def name = 'GSP Express'
        def us_mc_number = 1_480_261
      end
    end
  end
end
