module FreightKit
  module Carriers
    class SmithCargoTransportationServices < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Atlanta',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '1d2277ec-c692-4e8c-b270-c61a0dfc7aab',
              postal_code: '31192',
              region_abbreviation: 'GA',
              street: 'Dept At 952490'
            )
          ]
        end

        def id = '9d4c34e3-ce99-4610-a99e-1d7a503e2e0f'
        def name = 'Smith Cargo Transportation Services'
      end
    end
  end
end
