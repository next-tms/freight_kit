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
      rescue ArgumentError
        validate_packages(shipment.packages)
        # CarrierLogistics#validate_packages expects tariff argument but
        # customer Carrier Classes' #validate_packages expect only shipment.packages
      end

      request = build_rate_request(shipment:)
      response = commit(:rates, request)

      return response if response.is_a?(RateResponse)

      parse_rate_response(shipment:, response:)
    end
  end
end
