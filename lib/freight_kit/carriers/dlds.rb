# frozen_string_literal: true

module FreightKit
  class DLDS < CarrierLogistics
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

      def overlength_fees_require_tariff?
        false
      end
    end

    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Diamond Line Delivery'
    @@scac = 'DLDS'

    # Documents

    # Rates
    def build_calculated_accessorials(shipment)
      [].tap do |builder|
        builder << 'SS'
        builder << 'HAZ' if shipment.packages.any?(&:hazmat?)
      end
    end

    # Tracking

    # protected

    # Documents

    # Rates
  end
end
