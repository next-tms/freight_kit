module FreightKit
  module Carriers
    class FortTransportationAndServiceCompanyInc < Carrier
      class << self
        def contacts
          [
            Contact.new(
              department: 'Main',
              email: 'admin@shipwithfort.com',
              id: 'a7ba47b1-60d9-411f-93bc-77dc43a6639b',
              phone: '+19205630800'
            )
          ]
        end

        def headquarters
          Address.new(
            city: 'Fort Atkinson',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '347c9f8f-31c3-49bd-a097-586161732356',
            postal_code: '53538-2726',
            region_abbreviation: 'WI',
            street: '1600 Janesville Ave'
          )
        end

        def id = '8f39b3ca-de96-49ec-9fba-30ed3c99f08a'
        def legal_name = 'Fort Transportation And Service Company Inc'
        def name = 'Fort Transportation and Service'
        def scac = 'FTSC'
        def us_dot_number = 46_700
        def us_mc_number = 71_296
        def website_url = 'https://shipwithfort.com'
      end
    end
  end
end
