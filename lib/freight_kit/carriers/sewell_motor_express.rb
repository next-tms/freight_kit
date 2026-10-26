module FreightKit
  module Carriers
    class SewellMotorExpress < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '2d3cd00e-fc8e-4a1e-95cd-948667e5b0bd', phone: '+19373823847')]
        end

        def headquarters
          Address.new(
            city: 'Wilmington',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'f550e34c-83b5-4795-a537-f7a7325b688a',
            postal_code: '45177',
            region_abbreviation: 'OH',
            street: '370 Davids Drive'
          )
        end

        def id = '8868b780-9c04-4a1c-a0df-6b9cb3b06b47'
        def legal_name = 'Sewell Motor Express Co'
        def name = 'Sewell Motor Express'
        def us_dot_number = 258_149
        def us_mc_number = 57_992
        def website_url = 'https://go-sewell.com'
      end
    end
  end
end
