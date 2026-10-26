module FreightKit
  module Carriers
    class EstesExpressLines < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'City of Industry',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '5aac7b9b-5cd8-4b76-aabf-2af74f7ded70',
              postal_code: '91746',
              region_abbreviation: 'CA',
              street: '13327 Temple Ave'
            )
          ]
        end

        def id = 'b264b58b-ac96-4005-ab05-0baa25324621'
        def name = 'Estes Express Lines'
        def scac = 'EXLA'
        def website_url = 'https://www.estes-express.com'
      end
    end
  end
end
