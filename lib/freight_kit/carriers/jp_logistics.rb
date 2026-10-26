module FreightKit
  module Carriers
    class JPLogistics < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Kent',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '016fa873-4795-445f-b544-b75d69d62f62',
              postal_code: '98035',
              region_abbreviation: 'WA',
              street: 'PO Box 716'
            )
          ]
        end

        def contacts
          [Contact.new(department: 'Main', id: '079a5a86-0f03-42f0-9207-e94de82c2f90', phone: '+12534790126')]
        end

        def headquarters
          Address.new(
            city: 'Kent',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '29642f26-7964-415c-b8fb-a2a6ca858947',
            postal_code: '98032',
            region_abbreviation: 'WA',
            street: '21818 76th Avenue S'
          )
        end

        def id = 'bea02bf9-72d0-42f5-8913-60d8844835b6'
        def legal_name = 'JP Logistics Inc'
        def name = 'JP Logistics'
        def us_dot_number = 1_767_700
        def us_mc_number = 645_616
      end
    end
  end
end
