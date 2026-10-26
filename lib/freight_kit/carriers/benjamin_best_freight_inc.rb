module FreightKit
  module Carriers
    class BenjaminBestFreightInc < Carrier
      class << self
        def contacts
          [
            Contact.new(
              department: 'Main',
              email: 'dispatch@shipbbf.com',
              id: '4c511c55-596f-4ee2-9f94-35499780f653',
              phone: '+15137719378'
            )
          ]
        end

        def headquarters
          Address.new(
            city: 'West Chester',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '503edaba-1353-47fe-bc2a-1825684553d0',
            postal_code: '45069',
            region_abbreviation: 'OH',
            street: '6380 Centre Park Dr'
          )
        end

        def id = 'aaaad5ca-98c3-4f72-83ab-2690873eb98a'
        def legal_name = 'Benjamin Best Freight Inc'
        def name = 'Benjamin Best Freight'
        def scac = 'BBFG'
        def us_dot_number = 2_345_579
        def us_mc_number = 802_581
        def website_url = 'https://shipbbf.com'
      end
    end
  end
end
