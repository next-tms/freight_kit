module FreightKit
  module Platforms
    class NextTMS
      module ORM
        class BrokerCarrier < Base
          def account = @account ||= attribute(:account)
          def account_desc = @account_desc ||= attribute(:account_desc)
          def broker_customer = @broker_customer ||= fetch_association(:broker_customer)
          def carrier = @carrier ||= fetch_association(:carrier)
          def create_invoice_on_pickup? = attribute(:create_invoice_on_pickup)
          def days_to_pay_after_invoice_date = @days_to_pay_after_invoice_date ||= attribute(:days_to_pay_after_invoice_date)
          def shipments = @shipments ||= orm::Shipment.where(broker_carrier: self)
          def shipments_count = @shipments_count ||= attribute(:shipments_count)
        end
      end
    end
  end
end
