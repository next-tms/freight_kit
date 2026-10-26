module FreightKit
  module Carriers
    class TaxAirfreightInc < Carrier
      class << self
        def contacts
          [
            Contact.new(
              department: 'Main',
              email: 'dispatch@taxair.com',
              id: 'dc611a24-f1f8-4690-915a-f54216d8773b',
              phone: '+14147696565'
            )
          ]
        end

        def headquarters
          Address.new(
            city: 'Milwaukee',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '6e4d1954-52be-47ae-8b81-2f92e446198b',
            postal_code: '53207',
            region_abbreviation: 'WI',
            street: '5975 South Howell Avenue'
          )
        end

        def id = '66a00937-a549-4dcf-a9ee-2de989fc3cee'
        def legal_name = 'Tax Airfreight Inc'
        def name = 'Tax Airfreight'
        def scac = 'TAXA'
        def us_dot_number = 153_935
      end
    end
  end
end
