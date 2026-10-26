module FreightKit
  module Carriers
    class RoseTrucking < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Los Angeles',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '32d27651-0e38-4523-9ec0-78d8a17afd3f',
              postal_code: '90019',
              region_abbreviation: 'CA',
              street: '5506 Edgewood Pl'
            )
          ]
        end

        def id = '3c320a22-76a2-415b-ad98-98fc163ef712'
        def name = 'Rose Trucking'
        def scac = 'ROSE'
      end
    end
  end
end
