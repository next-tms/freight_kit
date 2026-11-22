module FreightKit
  # A shipment billed on an invoice (see {InvoiceResponse#lines}).
  #
  # @attribute balance_cents
  #   @return [Integer] What remains to be paid for the shipment.
  #
  # @attribute bol_number
  #   @return [String]
  #
  # @attribute delivered_on
  #   @return [Date]
  #
  # @attribute destination
  #   @return [FreightKit::Location]
  #
  # @attribute order_number
  #   @return [String]
  #
  # @attribute origin
  #   @return [FreightKit::Location]
  #
  # @attribute picked_up_on
  #   @return [Date]
  #
  # @attribute po_number
  #   @return [String]
  #
  # @attribute total_cents
  #   @return [Integer] What the invoice originally billed for the shipment.
  #
  # @attribute tracking_number
  #   @return [String]
  class InvoiceLine < Model
    attr_accessor :balance_cents,
                  :bol_number,
                  :delivered_on,
                  :destination,
                  :order_number,
                  :origin,
                  :picked_up_on,
                  :po_number,
                  :total_cents,
                  :tracking_number
  end
end
