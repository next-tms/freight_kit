module FreightKit
  module Carriers
    class SchneiderNational < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '16de7430-ff26-415a-817d-9acd2f5ca69f', phone: '+18005586767')]
        end

        def headquarters
          Address.new(
            city: 'Green Bay',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'f03995ec-487e-4b04-ad6b-6f5d4e9ccc36',
            postal_code: '54313',
            region_abbreviation: 'WI',
            street: '3101 South Packerland Drive'
          )
        end

        def id = '7f242e83-5194-4d2b-adee-0025dd7c00ff'
        def legal_name = 'Schneider National Carriers Inc'
        def name = 'Schneider National'
        def us_dot_number = 264_184
        def us_mc_number = 133_655
        def website_url = 'https://schneider.com'
      end
    end
  end
end
