module FreightKit
  module Carriers
    class RELogistics < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Corona del Mar',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '9b863fc1-e114-4a69-908a-c08dd18d8e2f',
              postal_code: '92625',
              region_abbreviation: 'CA',
              street: 'PO Box 910'
            )
          ]
        end

        def id = '65f1b231-59fa-4432-af2e-e5398b01bac6'
        def name = 'RE Logistics'
      end
    end
  end
end
