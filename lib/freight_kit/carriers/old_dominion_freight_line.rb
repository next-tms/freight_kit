module FreightKit
  module Carriers
    class OldDominionFreightLine < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'aea232d3-785c-4dbf-b178-6af92f5e9f28', phone: '+18002355569')]
        end

        def headquarters
          Address.new(
            city: 'Thomasville',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'da47bfa1-9c55-4784-b634-f09a2a5b10cc',
            postal_code: '27360-8923',
            region_abbreviation: 'NC',
            street: '500 Old Dominion Way'
          )
        end

        def id = '0ae69805-d3cc-41a9-8c29-bbd2fa4af818'
        def legal_name = 'Old Dominion Freight Line Inc'
        def name = 'Old Dominion Freight Line'
        def scac = 'ODFL'
        def us_dot_number = 90_849
        def us_mc_number = 107_478
        def website_url = 'https://www.odfl.com'
      end
    end
  end
end
