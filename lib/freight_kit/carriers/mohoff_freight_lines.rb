module FreightKit
  module Carriers
    class MohoffFreightLines < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Whittier',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '0159c6a0-171c-424e-a82f-10d65d14bd53',
              postal_code: '90609',
              region_abbreviation: 'CA',
              street: 'PO Box 1831'
            )
          ]
        end

        def id = '15cacada-895a-4e1c-91e3-eec395162aad'
        def name = 'Mohoff Freight Lines'
      end
    end
  end
end
