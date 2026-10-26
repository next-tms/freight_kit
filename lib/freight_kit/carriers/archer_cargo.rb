module FreightKit
  module Carriers
    class ArcherCargo < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Irvine',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'd05e7f81-6e46-4fbb-816b-9badb6e44d61',
              postal_code: '92614',
              region_abbreviation: 'CA',
              street: '1128 Spectrum'
            ),
            Address.new(
              city: 'Lemont',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'a053d643-a6db-4c33-91d4-4df946383fcf',
              postal_code: '60439',
              region_abbreviation: 'IL',
              street: '106 Stephen St Ste LL2'
            )
          ]
        end

        def id = 'a959a08a-afbd-4145-9fca-405e1c86c187'
        def legal_name = 'Archer Cargo LLC'
        def name = 'Archer Cargo'
        def scac = 'ARWG'
        def us_dot_number = 3_573_037
        def us_mc_number = 1_204_222
      end
    end
  end
end
