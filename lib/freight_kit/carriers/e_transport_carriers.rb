module FreightKit
  module Carriers
    class ETransportCarriers < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '8c0aff59-e11c-4c08-bbc8-3b61a8362ddc', phone: '+15703859048')]
        end

        def headquarters
          Address.new(
            city: 'Schuylkill Haven',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '7c5c7be2-198e-45e1-948f-1a063bf6d4cc',
            postal_code: '17972',
            region_abbreviation: 'PA',
            street: '100-110 W Columbia St'
          )
        end

        def id = 'edd5dbcf-f40c-4b78-86ad-8a26d29e250c'
        def legal_name = 'E-Transport Carriers LLC'
        def name = 'E-Transport Carriers'
        def us_dot_number = 1_067_244
        def us_mc_number = 438_912
        def website_url = 'https://evansdelivery.com'
      end
    end
  end
end
