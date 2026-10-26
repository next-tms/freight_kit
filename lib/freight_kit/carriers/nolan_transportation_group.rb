module FreightKit
  module Carriers
    class NolanTransportationGroup < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Atlanta',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'c73b2084-1dc0-44a2-8cba-e6e59585a6a5',
              postal_code: '31193',
              region_abbreviation: 'GA',
              street: 'PO Box 931184'
            )
          ]
        end

        def id = 'f49ac368-8e31-4798-b8ed-a759a7ee0b78'
        def legal_name = 'Nolan Transportation Group, LLC'
        def name = 'Nolan Transportation Group'
        def us_dot_number = 2_236_769
        def us_mc_number = 567_093
      end
    end
  end
end
