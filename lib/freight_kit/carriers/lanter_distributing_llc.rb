module FreightKit
  module Carriers
    class LanterDistributingLlc < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '18fee829-ec90-4f6d-8db2-e24afcf4d214', phone: '+16185123470')]
        end

        def headquarters
          Address.new(
            city: 'Madison',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '5ccf6389-bdfe-490f-867c-28ecc7bd20f7',
            postal_code: '62060',
            region_abbreviation: 'IL',
            street: '600 Madison Ave'
          )
        end

        def id = '84a39b82-0432-419d-95b0-80e7c6e86fa6'
        def legal_name = 'Lanter Distributing LLC'
        def name = 'Lanter Distributing'
        def scac = 'LRFD'
        def us_dot_number = 2_286_133
        def us_mc_number = 515_096
        def website_url = 'https://lanterdist.com'
      end
    end
  end
end
