module FreightKit
  # Represents the response to a {FreightKit::Carrier#invoice} call: what the invoice bills, and its document.
  #
  # @attribute balance_cents
  #   @return [Integer] What remains to be paid.
  #
  # @attribute currency
  #   @return [String] ISO 4217 code of the amounts.
  #
  # @attribute issued_on
  #   @return [Date]
  #
  # @attribute lines
  #   @return [Array<FreightKit::InvoiceLine>] The shipments billed.
  #
  # @attribute number
  #   @return [String] Invoice number.
  #
  # @attribute total_cents
  #   @return [Integer] What the invoice originally billed.
  class InvoiceResponse < DocumentResponse
    attr_accessor :balance_cents, :currency, :issued_on, :lines, :number, :total_cents
  end
end
