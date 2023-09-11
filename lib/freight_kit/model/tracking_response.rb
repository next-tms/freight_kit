# frozen_string_literal: true

module FreightKit
  module Model
    # Represents the response to a {FreightKit::Carrier#find_tracking_info} call.
    #
    # @note Some carriers provide more information than others, so not all attributes
    #   will be set, depending on what carrier you are using.
    #
    # @!attribute actual_delivery_date
    #   @return [DateTime]
    #
    # @!attribute attempted_delivery_date
    #   @return [DateTime]
    #
    # @!attribute carrier
    #   @return [Symbol]
    #
    # @!attribute carrier_name
    #   @return [String]
    #
    # @!attribute delivery_signature
    #   @return [String]
    #
    # @!attribute destination
    #   @return [FreightKit::Location]
    #
    # @!attribute estimated_delivery_date
    #   @return [FreightKit::DateTime]
    #
    # @!attribute origin
    #   @return [FreightKit::Location]
    #
    # @!attribute scheduled_delivery_date
    #   @return [DateTime]
    #
    # @!attribute ship_time
    #   @return [Date, Time]
    #
    # @!attribute shipment_events
    #   @return [Array<FreightKit::ShipmentEvent>]
    #
    # @!attribute shipper_address
    #   @return [FreightKit::Location]
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
    # @!attribute tracking_number
    #   @return [String]
    #
    class TrackingResponse < Response
      attr_accessor :actual_delivery_date,
                    :attempted_delivery_date,
                    :carrier,
                    :carrier_name,
                    :delivery_signature,
                    :destination,
                    :estimated_delivery_date,
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
end
