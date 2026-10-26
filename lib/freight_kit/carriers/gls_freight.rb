module FreightKit
  module Carriers
    class GLSFreight < Platforms::TheGreatInformationFactory
      class << self
        def id = '3fe9a02c-a99b-42d1-bf7e-3c110d1188ca'
        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(8, :feet)
        def name = 'GLS Freight'
        def scac = 'MTVL'
        def us_mc_number = 1_162_939
      end

      API = Platforms::TheGreatInformationFactory::API.deep_merge(
        domain: 'edifreight.gls-us.com',
        endpoints: {
          rates: '/web/services/TQUOTEAPIService/TQUOTEAPI?wsdl',
          track: '/web/services/TTRACKAPIService/TTRACKAPI?wsdl',
          pickup: '/web/services/TPICKUPAPIService/TPICKUPAPI?wsdl'
        },
        ports: { rates: 10_010, track: 10_010 }
      ).freeze

      def build_soap_header
        soap_header = super
        soap_header[:password] = soap_header[:password]&.downcase

        soap_header
      end
    end
  end
end
