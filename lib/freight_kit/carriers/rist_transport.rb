module FreightKit
  module Carriers
    class RISTTransport < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'cffdb46f-4943-400d-abc3-10efc8c3d7ad', phone: '+13157898871')]
        end

        def headquarters
          Address.new(
            city: 'Phelps',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'cf1e6922-7716-4605-9f12-36d42f221967',
            postal_code: '14532',
            region_abbreviation: 'NY',
            street: '369 Bostwick Rd'
          )
        end

        def id = '2e5e2c89-904a-4c56-b138-2fd869efc9f4'
        def legal_name = 'RIST Transport Ltd'
        def name = 'RIST Transport'
        def scac = 'HWEP'
        def us_dot_number = 285_525
        def us_mc_number = 193_781
      end
    end
  end
end
