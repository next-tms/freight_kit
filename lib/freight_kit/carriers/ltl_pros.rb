module FreightKit
  module Carriers
    class LTLPros < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '89b018a8-e92f-42e4-81f1-8ccbd2e803db', phone: '+19093501600')]
        end

        def headquarters
          Address.new(
            city: 'Ontario',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '5a820f55-8a02-480e-ba96-a438286623dd',
            postal_code: '91761',
            region_abbreviation: 'CA',
            street: '13610 S Archibald Ave'
          )
        end

        def id = '7fa1ebb6-50bd-428c-9d63-5d21bb78393a'
        def legal_name = 'LTL Pros Inc'
        def name = 'LTL Pros'
        def us_dot_number = 1_830_061
        def us_mc_number = 665_335
      end
    end
  end
end
