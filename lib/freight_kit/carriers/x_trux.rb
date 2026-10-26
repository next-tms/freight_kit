module FreightKit
  module Carriers
    class XTrux < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '9e66d05a-1623-4e84-983a-e718b6901518', phone: '+16055438357')]
        end

        def headquarters
          Address.new(
            city: 'Sioux Falls',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '29349d32-0aa0-475f-9515-acd9cfb4e946',
            postal_code: '57107-6438',
            region_abbreviation: 'SD',
            street: '47219 W Hobbs Cir'
          )
        end

        def id = '9925f319-9af9-4f57-888d-eae9a0f802f7'
        def legal_name = 'X-Trux Inc'
        def name = 'X-Trux'
        def us_dot_number = 841_776
        def us_mc_number = 375_851
        def website_url = 'https://xfreight.net'
      end
    end
  end
end
