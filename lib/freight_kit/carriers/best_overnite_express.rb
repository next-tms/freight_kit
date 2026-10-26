module FreightKit
  module Carriers
    class BestOverniteExpress < Platforms::TheGreatInformationFactory
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'City of Industry',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '3b35bf6c-91ee-42df-b2e1-1b5636638da5',
              postal_code: '91715',
              region_abbreviation: 'CA',
              street: 'PO Box 90816'
            )
          ]
        end

        def contacts
          [Contact.new(department: 'Main', id: '8d0dafe6-eae1-4892-a142-140ca98a4897', phone: '+16262560550')]
        end

        def headquarters
          Address.new(
            city: 'Irwindale',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '6743ac8d-bea6-44b3-9362-ac7d6fc1f359',
            postal_code: '91706',
            region_abbreviation: 'CA',
            street: '406 Live Oak Ave'
          )
        end

        def id = 'de8d8b03-170f-4d86-956b-fb87c024c257'
        def legal_name = 'Best Overnite Express Inc'
        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(8, :feet)
        def name = 'Best Overnite Express'
        def scac = 'BTVP'
        def us_dot_number = 589_562
      end

      include FreightKit::Documentable

      API = Platforms::TheGreatInformationFactory::API.deep_merge(
        actions: { rates: :getquote, track: :tracktrace, pickup: :requestpickup },
        domain: 'tgif1.bestovernite.com',
        domains: { pod: 'tgif.bestovernite.com', bol: 'tgif.bestovernite.com' },
        endpoints: {
          bol: '/cgi-bin/timageapi?doctype=BOL',
          pod: '/cgi-bin/timageapi?doctype=POD',
          rates: '/web/services/TQUOTEAPIService/TQUOTEAPI?wsdl',
          track: '/web/services/TTRACKAPIService/TTRACKAPI?wsdl',
          pickup: '/web/services/TPICKUPAPIService/TPICKUPAPI?wsdl'
        },
        ports: { rates: 10_032, track: 10_032, pickup: 10_032 },
        use_ssl: { pickup: false, bol: true, pod: true }
      ).freeze
      EVENTS = Platforms::TheGreatInformationFactory::EVENTS.deep_merge(
        locations: {
          '31': { city: 'Las Vegas', province: 'NV', state: 'NV' },
          '32': { city: 'Reno', province: 'NV', state: 'NV' },
          '50': { city: 'Phoenix', province: 'AZ', state: 'AZ' },
          '62': { city: 'Denver', province: 'CO', state: 'CO' },
          '71': { city: 'Salt Lake City', province: 'UT', state: 'UT' },
          'BEN': { city: 'Benicia', province: 'CA', state: 'CA' },
          'DAL': { city: 'Dallas', province: 'TX', state: 'TX' },
          'FRES': { city: 'Fresno', province: 'CA', state: 'CA' },
          'KENT': { city: 'Kent', province: 'WA', state: 'WA' },
          'LA': { city: 'Los Angeles', province: 'CA', state: 'CA' },
          'PDX': { city: 'Portland', province: 'OR', state: 'OR' },
          'SAC': { city: 'Sacramento', province: 'CA', state: 'CA' },
          'SJ': { city: 'San Jose', province: 'CA', state: 'CA' }
        }
      ).freeze
    end
  end
end
