# frozen_string_literal: true

module FreightKit
  module Trackable
    def find_tracking_info(tracking_number, *)
      request = build_tracking_request(tracking_number)
      begin
        # For SOAP APIs, the :action parameter is required
        response = commit(:track, request) if method(:commit).parameters.count == 2
        response ||= commit(request)
      rescue StandardError => e
        return TrackingResponse.new(error: e, request:)
      end

      return response if response.is_a?(TrackingResponse)

      if method(:parse_tracking_response).parameters.count == 1
        parse_tracking_response(response)
      else
        # Carrier Logistics requires tracking number argument
        parse_tracking_response(tracking_number, response:)
      end
    end
  end
end
