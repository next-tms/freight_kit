module Interstellar
  module Pickupable
    def create_pickup_implemented?
      true
    end

    def create_pickup(
      delivery_from:,
      delivery_to:,
      dispatcher:,
      pickup_from:,
      pickup_to:,
      scac:,
      service:,
      shipment:
    )
      request = build_pickup_request(
        delivery_from:,
        delivery_to:,
        dispatcher:,
        pickup_from:,
        pickup_to:,
        scac:,
        service:,
        shipment:
      )

      response = commit(:pickup, request)
      return response if response.is_a?(PickupResponse)

      parse_pickup_response(response)
    end
  end
end
