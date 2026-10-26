module FreightKit
  module Carriers
    class ChicagoSuburbanExpress < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'be066ad9-f8fb-46c5-9aab-3271dfb05024', phone: '+17084963300')]
        end

        def headquarters
          Address.new(
            city: 'Forest View',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '81fe3ab8-6748-4595-9d75-6074d76c2a00',
            postal_code: '60638',
            region_abbreviation: 'IL',
            street: '5504 W 47th Street'
          )
        end

        def id = '5f4a709b-949e-4f07-9fe3-70e87097b06f'
        def legal_name = 'Chicago Suburban Express Inc'
        def name = 'Chicago Suburban Express'
        def scac = 'CSEQ'
        def us_dot_number = 141_280
      end
    end
  end
end
