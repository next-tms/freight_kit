# frozen_string_literal: true

module Interstellar
  module Rateable
    class << self
      def included(base)
        base.send :extend, ClassMethods
      end
    end

    module ClassMethods
      def find_rates_implemented?
        true
      end
    end

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
