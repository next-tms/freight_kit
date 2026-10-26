module FreightKit
  module Carriers
    class DeepSouthFreight < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '5058bfcb-9d63-405a-8563-edc8de55df0a', phone: '+12053260490')]
        end

        def headquarters
          Address.new(
            city: 'Birmingham',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'c796119c-02d6-4a82-9de6-e3b8ba80b310',
            postal_code: '35204',
            region_abbreviation: 'AL',
            street: '2221 17th Street North'
          )
        end

        def id = 'f5d46839-6f1d-43be-94ef-1fda3e0b2b22'
        def legal_name = 'Tvs Inc'
        def name = 'Deep South Freight'
        def us_dot_number = 273_403
      end
    end
  end
end
