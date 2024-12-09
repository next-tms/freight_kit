# frozen_string_literal: true

module FreightKit
  class DCHA < CarrierLogistics
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

    cattr_reader :name, :scac
    @@name = 'DC Logistics'
    @@scac = 'DCHA'

    # Documents

    # Rates
    def build_calculated_accessorials(shipment)
      [].tap do |builder|
        builder << 'HAZM' if shipment.packages.any?(&:hazmat?)

        if shipment.accessorials.present? && %i[
residential_delivery
residential_pickup
].intersect?(shipment.accessorials)
          builder << 'RES'
        end

        longest_dimension = shipment.packages.map { |package| [package.length(:in), package.width(:in)].max }.max.ceil

        case longest_dimension
        when (144..155) then builder << 'XL12'
        when (156..167) then builder << 'XL13'
        when (168..179) then builder << 'XL14'
        when (180..191) then builder << 'XL15'
        when (192..203) then builder << 'XL16'
        when (204..215) then builder << 'XL17'
        when (216..227) then builder << 'XL18'
        when (228..239) then builder << 'XL19'
        when (240..251) then builder << 'XL20'
        when (252..483) then builder << 'XL21'
        when (484..275) then builder << 'XL22'
        when (276..287) then builder << 'XL23'
        when (288..299) then builder << 'XL24'
        when (300..311) then builder << 'XL25'
        when (312..323) then builder << 'XL26'
        when (324..) then builder << 'XL27'
        end
      end
    end

    # Tracking

    # protected

    # Documents

    # Rates
  end
end
