# frozen_string_literal: true

module FreightKit
  class MTVL < TheGreatInformationFactory
    class << self
      def maximum_height
        Measured::Length.new(105, :inches)
      end

      def maximum_weight
        Measured::Weight.new(10_000, :pounds)
      end

      def minimum_length_for_overlength_fees
        Measured::Length.new(8, :feet)
      end
    end

    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'GLS Freight'
    @@scac = 'MTVL'

    def build_soap_header
      soap_header = super
      soap_header[:password] = soap_header[:password]&.downcase

      soap_header
    end
  end
end
