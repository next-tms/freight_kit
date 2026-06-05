# frozen_string_literal: true

module FreightKit
  class CTBV < CarrierLogistics
    class << self
      def maximum_height
        Measured::Length.new(105, :inches)
      end

      def maximum_weight
        Measured::Weight.new(6999, :pounds)
      end

      def minimum_length_for_overlength_fees
        Measured::Length.new(8, :feet)
      end

      def overlength_fees_require_tariff?
        false
      end
    end

    REACTIVE_FREIGHT_CARRIER = true

    class << self
      attr_reader :name, :scac
    end
    @name = 'The Custom Companies'
    @scac = 'CTBV'

    # Documents

    # Rates
    def build_calculated_accessorials(shipment)
      [].tap do |builder|
        longest_dimension = shipment.packages.map { |package| [package.length(:in), package.width(:in)].max }.max.ceil

        case longest_dimension
        when (96..143) then builder << 'OL1'
        when (144..) then builder << 'OL'
        end
      end
    end

    # Tracking

    # protected

    # Documents

    # Rates
  end
end
