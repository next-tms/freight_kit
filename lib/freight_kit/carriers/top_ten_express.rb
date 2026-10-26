module FreightKit
  module Carriers
    class TopTenExpress < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'ddc7584d-22f3-4f70-8a9f-06bba733184c', phone: '+18003585990')]
        end

        def headquarters
          Address.new(
            city: 'Gurnee',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '1bf1b86a-92c0-49aa-a986-f562a4a0b6a7',
            postal_code: '60031-1206',
            region_abbreviation: 'IL',
            street: '2001 N Delany Rd'
          )
        end

        def id = '06cb58f8-4542-4ffc-aebc-98272678c78b'
        def legal_name = 'Top-ten Express Corp'
        def name = 'Top Ten Express'
        def us_dot_number = 1_625_877
        def us_mc_number = 600_068
      end
    end
  end
end
