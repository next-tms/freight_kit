module FreightKit
  module Carriers
    class AverittExpress < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'd4ae1484-bf60-4924-87e5-e95e9587e92c', phone: '+19315205059')]
        end

        def headquarters
          Address.new(
            city: 'Cookeville',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '6a12c769-c26b-44db-a5cc-9ce8396a5d8b',
            postal_code: '38501-4328',
            region_abbreviation: 'TN',
            street: '1415 Neal Street'
          )
        end

        def id = '7048c621-6898-4efc-a959-e21ccedbd683'
        def legal_name = 'Averitt Express Inc'
        def name = 'Averitt Express'
        def scac = 'AVRT'
        def us_dot_number = 36_684
        def us_mc_number = 843_369
        def website_url = 'https://www.averitt.com'
      end
    end
  end
end
