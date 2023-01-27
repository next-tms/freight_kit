# frozen_string_literal: true

module Interstellar
  module Trackable
    class << self
      def included(base)
        base.send :extend, ClassMethods
      end
    end

    module ClassMethods
      def find_tracking_info_implemented?
        true
      end
    end

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

      parse_tracking_response(response)
    end
  end
end
