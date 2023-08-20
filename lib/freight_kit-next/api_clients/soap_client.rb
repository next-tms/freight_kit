# frozen_string_literal: true

module FreightKit
  class SoapClient
    API_EXCEPTIONS = [
                       Savon::HTTPError,
                       Net::ReadTimeout,
                       Net::OpenTimeout,
                       Errno::ECONNREFUSED,
                       Errno::ECONNRESET,
                       Errno::EHOSTUNREACH,
                     ]

    def initialize(carrier:, action:, client_args:, call_args:, soap_operation:)
      @carrier = carrier
      @action = action
      @client_args = client_args
      @call_args = call_args
      @soap_operation = soap_operation
    end

    def call(handle_soap_fault_error: true)
      # http = OpenStruct.new(code: 500, body: {})
      # raise Savon::HTTPError, http

      api_exceptions = API_EXCEPTIONS
      api_exceptions += [Savon::SOAPFault] if handle_soap_fault_error

      # For testing and debugging
      # client_args = client_args.merge(
      #   logger: Rails.logger,
      #   log: true,
      #   pretty_print_xml: true
      # )

      Savon.client(
        **client_args,
      ).call(
        soap_operation,
        **call_args,
      ).body
    rescue *api_exceptions => e
      response = build_response_class(action:)
      response.error = ResponseError.new("HTTP Error: #{e}")

      response
    rescue Savon::InvalidResponseError
      response = build_response_class(action:)
      response.error = ResponseError.new('Invalid Response Error')

      response
    rescue StandardError => e
      response = build_response_class(action:)
      response.error = ResponseError.new("Unknown API Error #{e}")

      response
    end

    private

    attr_reader :carrier, :action, :client_args, :call_args, :soap_operation

    def build_response_class(action:)
      request = call_args[:message]

      case action
      when :rates then RateResponse.new(request:, response: nil)
      when :track then TrackingResponse.new(carrier:, request:, response: nil)
      when :pickup then PickupResponse.new(request:, response: nil)
      end
    end
  end
end
