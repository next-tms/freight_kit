module FreightKit
  module Carriers
    class LJExpress < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'El Segundo',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '5e8bed40-b3c8-4fce-bb40-e41b8fae55ba',
              postal_code: '90245',
              region_abbreviation: 'CA',
              street: '222 ca-1 10TH FLOOR'
            )
          ]
        end

        def id = 'd623279e-3899-4709-b8fc-8f105c0133cd'
        def name = 'LJ Express'
        def scac = 'LJEX'
      end
    end
  end
end
