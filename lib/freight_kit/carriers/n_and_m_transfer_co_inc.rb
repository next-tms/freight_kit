module FreightKit
  module Carriers
    class NAndMTransferCoInc < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '4ff2b22b-9aed-4d48-abc8-6596c9fe86c9', phone: '+18002364463')]
        end

        def headquarters
          Address.new(
            city: 'Neenah',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'b854100a-be8b-4c51-83f7-294d86c66518',
            postal_code: '54956',
            region_abbreviation: 'WI',
            street: '630 Muttart Rd'
          )
        end

        def id = '432e45d3-b122-40b3-92c7-6e4c578aed3c'
        def legal_name = 'N & M Transfer Co., Inc.'
        def name = 'N & M Transfer'
        def scac = 'NMTF'
        def us_dot_number = 191_755
        def us_mc_number = 154_495
      end
    end
  end
end
