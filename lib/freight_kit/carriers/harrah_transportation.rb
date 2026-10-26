module FreightKit
  module Carriers
    class HarrahTransportation < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'DFW Airport',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'c694a615-6cac-44fb-9086-254e12cc10f2',
              postal_code: '75261',
              region_abbreviation: 'TX',
              street: 'PO Box 610824'
            )
          ]
        end

        def id = '3708fc4f-5b34-4760-9757-5b6bb2a05ff8'
        def name = 'Harrah Transportation'
      end
    end
  end
end
