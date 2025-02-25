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

        if shipment.accessorials.present?
          builder << 'RESDEL' if shipment.accessorials.include?(:residential_delivery)
          builder << 'RESPIC' if shipment.accessorials.include?(:residential_pickup)
        end

        # @todo Update after determining why this doesn't generate resulting `chrg`

        # longest_dimension = shipment.packages.map { |package| [package.length(:in), package.width(:in)].max }.max.ceil

        # case longest_dimension
        # when (96..143) then builder << 'OVER8'
        # when (144..191) then builder << 'OVER12'
        # when (192..239) then builder << 'OVER16'
        # when (240..323) then builder << 'OVER20'
        # end
      end
    end

    # Tracking

    # protected

    # Documents

    # Rates
  end
end
