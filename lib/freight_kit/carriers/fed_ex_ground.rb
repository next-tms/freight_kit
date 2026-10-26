module FreightKit
  module Carriers
    class FedExGround < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Los Angeles',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'f01ddd68-c93a-4ba0-98ff-77370c9a328c',
              postal_code: '90046',
              region_abbreviation: 'CA',
              street: '7200 Frankli Ave #219'
            )
          ]
        end

        def id = 'f93c93f5-260d-431d-a9d0-95f9cd189da1'
        def name = 'FedEx Ground'
        def scac = 'FDEB'
      end
    end
  end
end
