module FreightKit
  module Carriers
    class CSATransportation < Carrier
      class << self
        def contacts
          [
            Contact.new(
              department: 'Dispatch - Los Angeles, CA',
              email: 'la@csatransportation.com',
              id: '5fb9d67e-df34-4320-842a-16a34a018e87'
            ),
            Contact.new(
              department: 'Customer Service - Vancouver, BC, Canada',
              id: 'aa12aaa2-d1e9-46a0-9925-00943a140fe0',
              phone: '+16042140006'
            )
          ]
        end

        def headquarters
          Address.new(
            city: 'Toronto',
            country: Countries.find_by(iso31661_alpha2: 'CA'),
            id: '7251a46e-5e7c-4c9f-81cf-1b9ff1061587',
            postal_code: 'M8W 1Z7',
            region_abbreviation: 'ON',
            street: '355 Horner Ave'
          )
        end

        def id = 'd90c6453-9f49-471b-afe4-18c79e5e9c98'
        def legal_name = '669779 Ontario Ltd'
        def name = 'CSA Transportation'
        def us_dot_number = 1_526_989
        def us_mc_number = 569_538
        def website_url = 'https://www.csatransportation.com'
      end
    end
  end
end
