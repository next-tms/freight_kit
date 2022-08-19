module Interstellar
  module Rateable
    def find_rates(shipment:)
      begin
        validate_packages(shipment.packages, @tariff)
      rescue UnserviceableError => e
        return RateResponse.new(error: e)
      end

      request = build_rate_request(shipment:)
      response = commit(:rates, request)

      return response if response.is_a?(RateResponse)

      parse_rate_response(shipment:, response: response)
    end
  end
end