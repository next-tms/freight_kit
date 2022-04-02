# frozen_string_literal: true

module Interstellar
  # `ShipmentEvent` is the abstract base class for all shipment events (usually
  # attached to `TrackingEresponse`).
  #
  # @!attribute location
  #   @return [Location] Location the event occurred.
  #
  # @!attribute type_code
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
  class ShipmentEvent < Model
    attr_reader :location, :time, :time_with_time_zone, :type_code
  end
end
