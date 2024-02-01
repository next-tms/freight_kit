# frozen_string_literal: true

module FreightKit
  class FCSY < CarrierLogistics
    class << self
      def maximum_height
        Measured::Length.new(105, :inches)
      end

      def maximum_weight
        Measured::Weight.new(10_000, :pounds)
      end

      def minimum_length_for_overlength_fees
        Measured::Length.new(12, :feet)
      end

      def overlength_fees_require_tariff?
        true
      end
    end

    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Frontline Freight'
    @@scac = 'FCSY'

    # Documents

    # Rates

    # Tracking

    # protected

    # Documents

    # Rates
  end
end
