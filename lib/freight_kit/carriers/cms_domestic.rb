module FreightKit
  module Carriers
    class CMSDomestic < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Denver',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '494c4cf7-3b71-4a5b-b274-afe316f37e46',
              postal_code: '80217',
              region_abbreviation: 'CO',
              street: 'PO Box 17769'
            )
          ]
        end

        def id = '272af805-19ad-4754-b26f-9177fc39c91d'
        def legal_name = 'Charles M. Schayer & Co.'
        def name = 'CMS Domestic'
        def us_dot_number = 2_249_786
      end
    end
  end
end
