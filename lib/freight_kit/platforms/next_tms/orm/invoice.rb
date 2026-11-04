module FreightKit
  module Platforms
    class NextTMS
      module ORM
        # What the API key's customer owes for a shipment. {NextTMS#invoice} downloads its document.
        class Invoice < Base
          def balance_cents = @balance_cents ||= attribute(:balance_cents)
          def balance_currency = @balance_currency ||= attribute(:balance_currency)
          def due_on = @due_on ||= date(:due_on)
          def issued_on = @issued_on ||= date(:issued_on)
          # The load ID
          def number = @number ||= attribute(:number)
          def paid_at = @paid_at ||= time(:paid_at)
          def shipment = @shipment ||= fetch_association(:shipment)
          def total_cents = @total_cents ||= attribute(:total_cents)
          def total_currency = @total_currency ||= attribute(:total_currency)
        end
      end
    end
  end
end
