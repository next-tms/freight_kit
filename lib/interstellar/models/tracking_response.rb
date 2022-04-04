# frozen_string_literal: true

module Interstellar
  # Represents the response to a {Interstellar::Carrier#find_tracking_info} call.
  #
  # @note Some carriers provide more information than others, so not all attributes
  #   will be set, depending on what carrier you are using.
  #
  # @!attribute carrier
  #   @return [Symbol]
  #
  # @!attribute carrier_name
  #   @return [String]
  #
  # @!attribute status
  #   @return [Symbol]
  #
  # @!attribute status_code
  #   @return [string]
  #
  # @!attribute status_description
  #   @return [String]
  #
  # @!attribute ship_time
  #   @return [Date, Time]
  #
  # @!attribute scheduled_delivery_date
  #   @return [DateTime]
  #
  # @!attribute actual_delivery_date
  #   @return [DateTime]
  #
  # @!attribute attempted_delivery_date
  #   @return [DateTime]
  #
  # @!attribute delivery_signature
  #   @return [String]
  #
  # @!attribute tracking_number
  #   @return [String]
  #
  # @!attribute shipment_events
  #   @return [Array<Interstellar::ShipmentEvent>]
  #
  # @!attribute shipper_address
  #   @return [Interstellar::Location]
  #
  # @!attribute origin
  #   @return [Interstellar::Location]
  #
  # @!attribute destination
  #   @return [Interstellar::Location]
  class TrackingResponse < Response
    attr_accessor :actual_delivery_date,
                  :attempted_delivery_date,
                  :carrier,
                  :carrier_name,
                  :delivery_signature,
                  :destination,
                  :origin,
                  :scheduled_delivery_date,
                  :ship_time,
                  :shipment_events,
                  :shipper_address,
                  :status,
                  :status_code,
                  :status_description,
                  :tracking_number
  end
end
