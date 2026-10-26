module FreightKit
  module Carriers
    class DuganTruckLine < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'fb400ad6-3d4f-4aca-b587-c6d79e3368b5', phone: '+13166169379')]
        end

        def headquarters
          Address.new(
            city: 'Wichita',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'd588aaf3-c7ab-4c43-bdd9-c086b89d1f93',
            postal_code: '67212',
            region_abbreviation: 'KS',
            street: '8525 W Central Ave'
          )
        end

        def id = '01eb426d-017a-44ee-8a6a-ee85238dab3d'
        def legal_name = 'Dugan Truck Line LLC'
        def name = 'Dugan Truck Line'
        def scac = 'DUBL'
        def us_dot_number = 1_494_870
        def website_url = 'https://dugantruckline.com'
      end
    end
  end
end
