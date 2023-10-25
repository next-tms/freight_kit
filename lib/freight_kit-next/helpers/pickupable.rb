# frozen_string_literal: true

module FreightKit
  module Pickupable
    class << self
      def included(base)
        base.send(:extend, ClassMethods)
      end
    end

    module ClassMethods
      def create_pickup_implemented?
        true
      end
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
        shipment:,
      )

      begin
        # For SOAP APIs, the :action parameter is required
        response = commit(:pickup, request) if method(:commit).parameters.count == 2
        response ||= commit(request)
      rescue FreightKit::Error => error
        response = PickupResponse.new(request:, response: nil, error:)
      end

      return response if response.is_a?(PickupResponse)

      parse_pickup_response(response)
    end
  end
end
