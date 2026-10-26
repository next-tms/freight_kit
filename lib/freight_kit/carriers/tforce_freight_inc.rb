module FreightKit
  module Carriers
    class TforceFreightInc < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '0fdc5e3b-54c0-43b8-ab1f-db45568a80ca', phone: '+18003337400')]
        end

        def headquarters
          Address.new(
            city: 'Henrico',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'a64510d0-a59a-41b0-a24c-cc73f18b114b',
            postal_code: '23233',
            region_abbreviation: 'VA',
            street: '9954 Mayland Drive Suite 3000'
          )
        end

        def id = 'ec416c3d-38ae-49fc-a821-ee4f7cc684fa'
        def legal_name = 'Tforce Freight Inc'
        def name = 'TForce Freight'
        def scac = 'TFIN'
        def us_dot_number = 121_058
        def us_mc_number = 109_533
        def website_url = 'https://www.tforcefreight.com'
      end
    end
  end
end
