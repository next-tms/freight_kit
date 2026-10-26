module FreightKit
  module Carriers
    class AlohaFreightForwarders < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Compton',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '7cbdc89e-65c5-43e6-a03e-26965af5642d',
              postal_code: '90220',
              region_abbreviation: 'CA',
              street: '1800 S Anderson Ave'
            )
          ]
        end

        def contacts
          [
            Contact.new(
              department: 'Rating',
              email: 'rates@alohafreight.com',
              id: '5de89baa-e0df-4374-a3be-018251dd6f4e'
            )
          ]
        end

        def id = '3df63da7-cb62-4474-bc04-40ec732aa4aa'
        def name = 'Aloha Freight Forwarders'
        def scac = 'TXWL'
        def website_url = 'https://www.alohafreight.com'
      end
    end
  end
end
