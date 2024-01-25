# frozen_string_literal: true

module FreightKit
  module Rateable
    def find_rates(shipment:)
      begin
        validate_packages(shipment.packages, @tariff)
      rescue UnserviceableError => e
        return RateResponse.new(error: e)
      end

      request = build_rate_request(shipment:)

      # For SOAP APIs, the :action parameter is required
      response = commit(:rates, request) if method(:commit).parameters.count == 2
      response ||= commit(request)

      return response if response.is_a?(RateResponse)

      parse_rate_response(shipment:, response:)
    end
  end
end
