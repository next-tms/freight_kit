# frozen_string_literal: true

module FreightKit
  module Model
    # `ShipmentEvent` is the abstract base class for all shipment events (usually
    # attached to `TrackingEresponse`).
    #
    # @attribute date_time
    #   @return [DateTime] Date and time the event occurred.
    #
    # @attribute location
    #   @return [Location] Location the event occurred.
    #
    # @attribute type_code
    #   @return [Symbol] One of:
    #     ```
    #       :arrived_at_terminal
    #       :delayed_due_to_weather
    #       :delivered
    #       :delivery_appointment_scheduled
    #       :departed
    #       :found
    #       :located
    #       :lost
    #       :out_for_delivery
    #       :pending_delivery_appointment
    #       :picked_up
    #       :pickup_driver_assigned
    #       :pickup_information_received_by_carrier
    #       :pickup_information_sent_to_carrier
    #       :sailed
    #       :trailer_closed
    #       :trailer_unloaded
    #     ```
    #
    class ShipmentEvent < Base
      attr_accessor :date_time, :location, :type_code
    end
  end
end
