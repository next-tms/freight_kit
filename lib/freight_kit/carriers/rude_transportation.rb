module FreightKit
  module Carriers
    class RudeTransportation < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'd7182baf-a0a4-4d97-b61b-8234aec69b63', phone: '+16053356575')]
        end

        def headquarters
          Address.new(
            city: 'Sioux Falls',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'a4cdeadd-f066-4b7b-84cb-bb06d3c03732',
            postal_code: '57107-0542',
            region_abbreviation: 'SD',
            street: '200 S Marion Rd'
          )
        end

        def id = 'fe7dd5c8-85c1-4e6b-97e5-ffab31859ad4'
        def legal_name = 'Rude Transportation Inc'
        def name = 'Rude Transportation'
        def scac = 'RUDE'
        def us_dot_number = 1_391
        def us_mc_number = 64_732
        def website_url = 'https://www.rudetransportation.com'
      end
    end
  end
end
