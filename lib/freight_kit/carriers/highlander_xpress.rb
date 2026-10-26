module FreightKit
  module Carriers
    class HighlanderXpress < Carrier
      class << self
        def contacts
          [
            Contact.new(
              department: 'Main',
              email: 'info@highlanderxpress.com',
              id: '3177cf58-2c65-4727-9f4a-ad8145df287e',
              phone: '+17863360601'
            )
          ]
        end

        def headquarters
          Address.new(
            city: 'Miami',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '481250e2-8718-456a-aefe-3e5d5a4f7ecb',
            postal_code: '33166',
            region_abbreviation: 'FL',
            street: '7100 NW 77 Ct'
          )
        end

        def id = 'fa799de3-9113-43cd-b8eb-5094cad47bc5'
        def legal_name = 'Highlander Xpress Inc'
        def name = 'Highlander Xpress'
        def us_dot_number = 1_150_323
        def us_mc_number = 464_547
        def website_url = 'https://highlanderxpress.com'
      end
    end
  end
end
