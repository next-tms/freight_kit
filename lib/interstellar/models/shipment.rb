# frozen_string_literal: true

module Interstellar
  # Shipment is the abstract base class for all rate requests.
  #
  # @!attribute accessorials [Hash<Symbol>] Acceessorials requested.
  # @!attribute declared_value_cents [Integer] Declared value in cents.
  # @!attribute destination [Interstellar::Location] Where the package will go.
  # @!attribute origin [Interstellar::Location] Where the shipment will originate from.
  # @!attribute order_number [String] Order number (also known as shipper number, SO #).
  # @!attribute packages [Array<Interstellar::Package>] The list of packages that will
  #   be in the shipment.
  # @!attribute po_number [String] Purchase order number (also known as PO #).
  class Shipment < Model
    attr_accessor :accessorials, :declared_value_cents, :destination, :origin, :order_number, :packages, :po_number

    def initialize(attributes = {})
      assign_attributes(attributes)
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
