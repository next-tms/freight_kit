module FreightKit
  module Carriers
    class GholiaBrosTrucking < Carrier
      class << self
        def contacts
          [
            Contact.new(
              department: 'Main',
              email: 'dispatch@gholiabrostrucking.com',
              id: 'aef61450-192f-473b-875a-2570260bd8c2',
              phone: '+12536392630'
            )
          ]
        end

        def headquarters
          Address.new(
            city: 'Kent',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '2576f93d-670d-4b44-a666-b22b7bae9bc2',
            postal_code: '98042',
            region_abbreviation: 'WA',
            street: '14128 SE 281st Pl'
          )
        end

        def id = 'd77eddd1-51e3-4e0a-a217-1f713a7bf141'
        def legal_name = 'Gholia Bros Trucking LLC'
        def name = 'Gholia Bros Trucking'
        def us_dot_number = 1_393_524
        def us_mc_number = 532_386
        def website_url = 'https://gholiabrostrucking.com'
      end
    end
  end
end
