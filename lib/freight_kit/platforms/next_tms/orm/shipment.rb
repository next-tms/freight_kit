module FreightKit
  module Platforms
    class NextTMS
      module ORM
        class Shipment < Base
          class << self
            def association_type_mapping = super.merge(receiver_address: 'Address', shipper_address: 'Address')
          end

          def bol = @bol ||= attribute(:bol)
          def booked_at = @booked_at ||= time(:booked_at)
          def broker_carrier = @broker_carrier ||= fetch_association(:broker_carrier)
          def broker_customer = @broker_customer ||= fetch_association(:broker_customer)
          def canceled_at = @canceled_at ||= time(:canceled_at)
          def created_at = @created_at ||= time(:created_at)
          def customer_reference = @customer_reference ||= attribute(:customer_reference)
          def delivered_at = @delivered_at ||= time(:delivered_at)
          def delivery_appointment_at = @delivery_appointment_at ||= time(:delivery_appointment_at)
          def delivery_appointment_on = @delivery_appointment_on ||= date(:delivery_appointment_on)
          def delivery_eta_on = @delivery_eta_on ||= date(:delivery_eta_on)
          def departed_origin_terminal_at = @departed_origin_terminal_at ||= time(:departed_origin_terminal_at)
          def dispatched_at = @dispatched_at ||= time(:dispatched_at)

          # The carrier's scans, oldest first, as hashes with `occurred_at` and `type_code`, a {ShipmentEvent#type_code}
          def events = @events ||= Array(attribute(:events))

          def load_id = @load_id ||= attribute(:load_id)
          def lost_on = @lost_on ||= date(:lost_on)
          def out_for_delivery_at = @out_for_delivery_at ||= time(:out_for_delivery_at)
          def pending_appointment_since = @pending_appointment_since ||= date(:pending_appointment_since)
          def picked_up_at = @picked_up_at ||= time(:picked_up_at)
          def pickup_driver_assigned_at = @pickup_driver_assigned_at ||= time(:pickup_driver_assigned_at)
          def pickup_on = @pickup_on ||= date(:pickup_on)
          def pro = @pro ||= attribute(:pro)
          def receiver_address = @receiver_address ||= fetch_association(:receiver_address)
          def receiver_name = @receiver_name ||= attribute(:receiver_name)
          def shipper_address = @shipper_address ||= fetch_association(:shipper_address)
          def shipper_bol = @shipper_bol ||= attribute(:shipper_bol)
          def shipper_name = @shipper_name ||= attribute(:shipper_name)
          def shipper_reference = @shipper_reference ||= attribute(:shipper_reference)
          def status = @status ||= attribute(:status)&.to_sym
          def total_charges_cents = @total_charges_cents ||= attribute(:total_charges_cents)
          def total_charges_currency = @total_charges_currency ||= attribute(:total_charges_currency)
          def truckload? = attribute(:truckload)
          def updated_at = @updated_at ||= time(:updated_at)
        end
      end
    end
  end
end
