module FreightKit
  module Carriers
    class NumarkTransportation < Platforms::TheGreatInformationFactory
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Fresno',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '88bbf0d6-8f6d-4b50-91f9-408c86ac5bb7',
              postal_code: '93725',
              region_abbreviation: 'CA',
              street: '2737 S East Ave'
            )
          ]
        end

        def contacts
          [Contact.new(department: 'Main', id: 'fcfb038c-8863-4cd0-aa1b-c429dfb9390a', phone: '+15594863113')]
        end

        def headquarters
          Address.new(
            city: 'Fresno',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '8c116efd-cdd6-48a1-8098-ea2e5db41524',
            postal_code: '93725',
            region_abbreviation: 'CA',
            street: '2737 S East Ave'
          )
        end

        def id = '2a1d0b5f-0b1f-4b22-b0a8-ef1906f77a01'
        def legal_name = 'Numark Transportation Inc'
        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(4, :ft)
        def name = 'Numark Transportation'
        def overlength_fees_require_tariff? = false
        def requirements = %i[credentials]
        def scac = 'NUMK'
        def us_dot_number = 1_075_162
        def us_mc_number = 439_902
      end

      include FreightKit::Documentable

      API = Platforms::TheGreatInformationFactory::API.deep_merge(
        domain: 'tracking.numarktransportation.net',
        endpoints: {
          bol: '/cgibin/timageapi?doctype=BOL',
          pod: '/cgibin/timageapi?doctype=POD',
          rates: '/web/services/TQUOTEAPI?wsdl',
          track: '/web/services/TTRACKAPI?wsdl',
          pickup: '/web/services/TPICKUPAPI?wsdl'
        },
        ports: { rates: 10_010, track: 10_010 }
      ).freeze

      def build_calculated_accessorials(packages)
        longest_dimension = packages.map { |package| [package.length(:in), package.width(:in)].max }.max.ceil

        return ['OVER'] if longest_dimension > 48

        []
      end

      def build_soap_header
        soap_header = super
        soap_header[:password] = soap_header[:password]&.downcase

        soap_header
      end

      protected

      def wrap_request(request) = { 'args0' => request }
    end
  end
end
