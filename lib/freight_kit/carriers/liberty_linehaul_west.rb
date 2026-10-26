module FreightKit
  module Carriers
    class LibertyLinehaulWest < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '9a7478b2-4635-436b-b007-06f89f8f6e57', phone: '+13237288900')]
        end

        def headquarters
          Address.new(
            city: 'Montebello',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'e31ebd17-0059-4bf0-b22e-be3c7e4886c1',
            postal_code: '90640',
            region_abbreviation: 'CA',
            street: '1501 Chapin Road'
          )
        end

        def id = '9191ac06-8b97-40a4-ab26-71a8a41ebbc4'
        def legal_name = 'Liberty Linehaul West Inc'
        def name = 'Liberty Linehaul West'
        def us_dot_number = 691_117
        def us_mc_number = 320_367
      end
    end
  end
end
