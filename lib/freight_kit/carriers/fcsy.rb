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
        false
      end
    end

    REACTIVE_FREIGHT_CARRIER = true

    class << self
      attr_reader :name, :scac
    end
    @name = 'STG'
    @scac = 'FCSY'

    # Documents

    # Rates

    def build_calculated_accessorials(shipment)
      [].tap do |builder|
        longest_dimension = shipment.packages.map { |package| [package.length(:in), package.width(:in)].max }.max.ceil

        case longest_dimension
        when (96..143) then builder << 'XTRM8'
        when (144..191) then builder << 'XTRM12'
        when (192..239) then builder << 'XTRM16'
        when (240..311) then builder << 'XTRM20'
        when (312..) then builder << 'XTRM27'
        end
      end
    end

    # Tracking

    # protected

    # Documents

    # Rates
  end
end
