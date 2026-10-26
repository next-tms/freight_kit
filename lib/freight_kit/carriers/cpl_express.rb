module FreightKit
  module Carriers
    class CPLExpress < Carrier
      class << self
        def contacts
          [
            Contact.new(
              department: 'Dispatch',
              email: 'dispatch@cplexpress.com',
              id: 'ba43e014-2e59-43d6-8f39-acb80128b8c9'
            ),
            Contact.new(department: 'Main', id: 'a7daa1e5-4abb-48de-9893-493e91806a83', phone: '+13104189008')
          ]
        end

        def headquarters
          Address.new(
            city: 'Santa Fe Springs',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '851dd7b4-b07a-46d2-af99-4cc76de0d15b',
            postal_code: '90670',
            region_abbreviation: 'CA',
            street: '10715 Springdale Avenue #5'
          )
        end

        def id = '5d814738-f7b8-4727-b44c-d899f5e116e0'
        def legal_name = 'CPL Express Inc'
        def name = 'CPL Express'
        def us_dot_number = 1_376_496
        def us_mc_number = 525_362
      end
    end
  end
end
