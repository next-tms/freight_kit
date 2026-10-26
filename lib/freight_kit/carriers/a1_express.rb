module FreightKit
  module Carriers
    class A1Express < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Vernon',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'b6c55625-c4f0-42d0-aef3-067b70fc6f3e',
              postal_code: '90058',
              region_abbreviation: 'CA',
              street: '4520 S Maywood Ave'
            )
          ]
        end

        def consider_bol_and_pod_documents_same? = true
        def id = 'e899224d-f3c9-47b5-9e2f-61c9c0d8c497'
        def name = 'A1 Express'
        def scac = 'AOXQ'
      end
    end
  end
end
