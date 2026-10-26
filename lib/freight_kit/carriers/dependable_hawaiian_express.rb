module FreightKit
  module Carriers
    class DependableHawaiianExpress < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Hayward',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '7e9bf6a0-1bf8-45e6-8808-87045bd286e2',
              postal_code: '94545',
              region_abbreviation: 'CA',
              street: 'PO Box 57136'
            )
          ]
        end

        def id = '0388971f-0ebb-4a03-b6e4-37c3afb098fb'
        def name = 'Dependable Hawaiian Express'
        def scac = 'HSXF'
      end
    end
  end
end
