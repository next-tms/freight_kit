module FreightKit
  module Carriers
    class ZentnerTransportation < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '268a3b40-b03a-4600-839a-478223ed0bca', phone: '+13083580291')]
        end

        def headquarters
          Address.new(
            city: 'Cedar Rapids',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'bd418b64-abb8-47ef-b6aa-5298a4e5bd80',
            postal_code: '68627',
            region_abbreviation: 'NE',
            street: '612 S Third Street'
          )
        end

        def id = 'd46277ce-db54-46b5-8310-02b1f84524ee'
        def legal_name = 'Zentner Transportation Inc'
        def name = 'Zentner Transportation'
        def us_dot_number = 239_232
        def website_url = 'https://zentnertransportation.com'
      end
    end
  end
end
