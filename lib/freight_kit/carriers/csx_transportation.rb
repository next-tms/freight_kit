module FreightKit
  module Carriers
    class CSXTransportation < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Atlanta',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'c9210256-1316-41e9-8ff6-23b94f52f6a9',
              postal_code: '30353',
              region_abbreviation: 'GA',
              street: 'PO Box 532601'
            )
          ]
        end

        def contacts
          [Contact.new(department: 'Main', id: '46196ba3-6636-414d-8b07-cc83c99ce960', phone: '+18002320144')]
        end

        def headquarters
          Address.new(
            city: 'Jacksonville',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'd720e677-7499-4c8e-af96-3163ccf248f5',
            postal_code: '32202-4423',
            region_abbreviation: 'FL',
            street: '500 Water St'
          )
        end

        def id = '0d9f649c-c591-4d49-b50d-b1029dd67086'
        def legal_name = 'CSX Transportation Inc'
        def name = 'CSX Transportation'
        def us_dot_number = 29_619
      end
    end
  end
end
