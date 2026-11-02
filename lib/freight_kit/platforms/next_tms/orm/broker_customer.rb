module FreightKit
  module Platforms
    class NextTMS
      module ORM
        class BrokerCustomer < Base
          class << self
            def association_type_mapping = super.merge(office_address: 'Address', primary_pickup_address: 'Address')
          end

          def accounting_customer_id = @accounting_customer_id ||= attribute(:accounting_customer_id)
          def broker_carriers = @broker_carriers ||= orm::BrokerCarrier.where(broker_customer: self)
          def can_quote? = attribute(:can_quote)
          def customer = @customer ||= fetch_association(:customer)
          def office_address = @office_address ||= fetch_association(:office_address)
          def primary_pickup_address = @primary_pickup_address ||= fetch_association(:primary_pickup_address)
          def shipments = @shipments ||= orm::Shipment.where(broker_customer: self)
          def valid_freight_classes = @valid_freight_classes ||= attribute(:valid_freight_classes)
        end
      end
    end
  end
end
