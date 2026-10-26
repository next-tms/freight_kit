module FreightKit
  module Carriers
    class JasperTrucking < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '33f8e019-6ccd-425c-a616-948580482a47', phone: '+12606939349')]
        end

        def headquarters
          Address.new(
            city: 'Albion',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '2eb5a045-a4d6-4300-9231-c4736052533a',
            postal_code: '46701',
            region_abbreviation: 'IN',
            street: '4355 S State Road 9'
          )
        end

        def id = '6ebc3e22-ba67-4118-a65f-c570f8f03408'
        def legal_name = 'Jasper Trucking Inc'
        def name = 'Jasper Trucking'
        def us_dot_number = 591_449
        def us_mc_number = 258_266
      end
    end
  end
end
