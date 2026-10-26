module FreightKit
  module Carriers
    class WesternFlyerExpress < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '07fa769e-0fcb-4243-ad22-61cee51cdc8e', phone: '+14059467289')]
        end

        def headquarters
          Address.new(
            city: 'Oklahoma City',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'ffbcd0d1-df4d-49e8-80f9-ed4a5de2a359',
            postal_code: '73108',
            region_abbreviation: 'OK',
            street: '4050 West I-40 Service Rd'
          )
        end

        def id = '2c415921-17f6-4e8b-87f6-f0bfb36d5fa9'
        def legal_name = 'Western Flyer Express LLC'
        def name = 'Western Flyer Express'
        def us_dot_number = 658_909
        def us_mc_number = 309_036
      end
    end
  end
end
