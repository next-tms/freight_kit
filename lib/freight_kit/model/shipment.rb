# frozen_string_literal: true

module FreightKit
  module Model
    # Shipment is the abstract base class for all rate requests.
    #
    # @!attribute accessorials [Hash<Symbol>] Acceessorials requested.
    # @!attribute declared_value_cents [Integer] Declared value in cents.
    # @!attribute destination [FreightKit::Location] Where the package will go.
    # @!attribute origin [FreightKit::Location] Where the shipment will originate from.
    # @!attribute order_number [String] Order number (also known as shipper number, SO #).
    # @!attribute packages [Array<FreightKit::Package>] The list of packages that will
    #   be in the shipment.
    # @!attribute po_number [String] Purchase order number (also known as PO #).
    # @!attribute pickup_at [FreightKit::DateTime] Pickup date/time.
    class Shipment < Base
      attr_accessor :accessorials,
                    :declared_value_cents,
                    :destination,
                    :origin,
                    :order_number,
                    :packages,
                    :po_number,
                    :pro
      attr_reader :pickup_at

      def loose?
        return false if @packages.blank?

        packages.map(&:packaging).map(&:pallet?).none?(true)
      end

      def hazmat?
        packages.map(&:hazmat?).any?(true)
      end

      def loose_and_palletized?
        !loose? && !palletized?
      end

      def palletized?
        return false if @packages.blank?

        packages.map(&:packaging).map(&:pallet?).none?(false)
      end

      def pickup_at=(date_time)
        if date_time.is_a?(ActiveSupport::TimeWithZone)
          @pickup_at = FreightKit::DateTime.new(date_time_with_zone: date_time)
          return
        end

        raise ArgumentError, 'date_time must be an FreightKit::DateTime' unless date_time.is_a?(DateTime)

        @pickup_at = date_time
      end

      def valid?
        return false if @accessorials.nil?
        return false unless @destination.is_a?(Location)
        return false unless @packages.is_a?(Array)
        return false if @packages.any? { |p| p.class != Package }

        true
      end
    end
  end
end
