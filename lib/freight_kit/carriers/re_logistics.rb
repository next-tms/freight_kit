module FreightKit
  module Carriers
    class RELogistics < Platforms::RoadVision
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
        def legal_name = 'RE Logistics Corp'
        def name = 'RE Logistics'
        def scac = 'RELM'
        def us_dot_number = 3_236_760
        def us_mc_number = 1_015_860
      end
    end
  end
end
