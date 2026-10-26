module FreightKit
  module Carriers
    class JustInTimeCargo < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '77735371-39d8-41ac-b9e6-ce2c21b9a188', phone: '+19492076428')]
        end

        def headquarters
          Address.new(
            city: 'Fort Worth',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '2914d8ca-acc4-4484-bfa5-f77b7d1a4f7b',
            postal_code: '76155',
            region_abbreviation: 'TX',
            street: '15825 W Trinity Blvd'
          )
        end

        def id = '3499e852-30e6-46d6-bbba-4f160012e10b'
        def legal_name = 'Just In Time Cargo Inc'
        def name = 'Just In Time Cargo'
        def us_dot_number = 2_129_045
        def us_mc_number = 741_660
        def website_url = 'https://jitclogistics.com'
      end
    end
  end
end
