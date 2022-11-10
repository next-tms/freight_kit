module Interstellar
  module Trackable
    def find_tracking_info_implemented?
      true
    end

    def find_tracking_info(tracking_number, *)
      request = build_tracking_request(tracking_number)
      response = commit(:track, request)

      return response if response.is_a?(TrackingResponse)

      parse_tracking_response(response)
    end
  end
end