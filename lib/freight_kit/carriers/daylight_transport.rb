module FreightKit
  module Carriers
    class DaylightTransport < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '5a5258d8-4353-4e94-bde2-105cc3143099', phone: '+18004689999')]
        end

        def headquarters
          Address.new(
            city: 'Cypress',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'abb2048d-eef6-472c-b6a0-be0567f1203f',
            postal_code: '90630',
            region_abbreviation: 'CA',
            street: '5660 Katella Ave Suite 250'
          )
        end

        def id = '1ae7d8cc-725c-4043-bb7a-3e61821dbe10'
        def legal_name = 'Daylight Transport LLC'
        def name = 'Daylight Transport'
        def scac = 'DYLT'
        def us_dot_number = 898_079
        def us_mc_number = 390_739
      end
    end
  end
end
