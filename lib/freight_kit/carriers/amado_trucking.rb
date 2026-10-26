module FreightKit
  module Carriers
    class AmadoTrucking < Carrier
      class << self
        def contacts
          [
            Contact.new(
              department: 'Dispatch',
              email: 'la.dispatch@amadotrucking.com',
              id: 'c5dab2fd-b178-41f7-bc2b-3f53f8717c01'
            )
          ]
        end

        def headquarters
          Address.new(
            city: 'Nogales',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '0b430b32-036f-46c2-aeef-e4ab906b4175',
            postal_code: '85621-4521',
            region_abbreviation: 'AZ',
            street: '1430 N Mariposa Rd'
          )
        end

        def id = '92ba89c5-746a-47ee-afd7-b93614b0e167'
        def legal_name = 'Amado Trucking Inc'
        def name = 'Amado Trucking'
        def us_dot_number = 241_605
        def us_mc_number = 181_180
        def website_url = 'https://www.amadotrucking.com'
      end
    end
  end
end
