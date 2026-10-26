module FreightKit
  module Carriers
    class TransInternationalTrucking < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'db3a6cfc-b623-4730-bad6-02036b048b7a', phone: '+18779345283')]
        end

        def headquarters
          Address.new(
            city: 'Wilmington',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'e55ca138-9a1f-4062-b86b-766f720497e9',
            postal_code: '90744',
            region_abbreviation: 'CA',
            street: '2401 E Pacific Coast Hwy Whse #16'
          )
        end

        def id = 'b7f72bc1-191e-45ae-b21d-af25a6dcce2a'
        def legal_name = 'Trans International Trucking Inc'
        def name = 'Trans International Trucking'
        def us_dot_number = 732_271
        def us_mc_number = 334_708
        def website_url = 'https://transinttrucking.com'
      end
    end
  end
end
