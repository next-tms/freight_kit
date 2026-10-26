module FreightKit
  module Carriers
    class MSFreight < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'e819bac5-4573-41c0-bd35-b48dfef3de87', phone: '+16623072705')]
        end

        def headquarters
          Address.new(
            city: 'Grenada',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'b9de7f9a-39e9-4c5b-98ee-2fe97d77ac76',
            postal_code: '38901',
            region_abbreviation: 'MS',
            street: '1283 Lakeview Drive'
          )
        end

        def id = '8f47af6c-98fe-4457-8de9-18d5f82d2b20'
        def legal_name = 'MS Freight Company Inc'
        def name = 'MS Freight'
        def us_dot_number = 2_090_356
      end
    end
  end
end
