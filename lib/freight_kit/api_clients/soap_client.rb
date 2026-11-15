module FreightKit
  class SoapClient
    API_EXCEPTIONS = [
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH,
      HTTPX::ConnectionError,
      HTTPX::TimeoutError,
      Savon::HTTPError
    ].freeze

    WSDL_CACHE_HEADERS = ['cache-control', 'etag', 'expires', 'last-modified'].freeze
    WSDL_EXPIRES_IN = 1.day
    WSDL_NAMESPACE = 'freight_kit/soap_client/wsdl'.freeze

    def initialize(carrier:, action:, client_args:, call_args:, soap_operation:)
      @carrier = carrier
      @action = action
      @client_args = client_args || {}
      @call_args = call_args
      @soap_operation = soap_operation
    end

    def call(handle_soap_fault_error: true)
      # http = OpenStruct.new(code: 500, body: {})
      # raise Savon::HTTPError, http

      api_exceptions = API_EXCEPTIONS

      # For testing and debugging
      # client_args.merge!(log: true, pretty_print_xml: true)

      Savon.client(**savon_args).call(soap_operation, **call_args).body
    rescue *api_exceptions => e
      response = build_response_class(action:)
      response.error = ResponseError.new("Network Error: #{e}")

      response
    rescue Savon::InvalidResponseError
      response = build_response_class(action:)
      response.error = ResponseError.new('API Error: Invalid response')

      response
    rescue Savon::SOAPFault => e
      raise unless handle_soap_fault_error

      response = build_response_class(action:)
      response.error = ResponseError.new("API Error: #{e}")

      response
    rescue StandardError => e
      response = build_response_class(action:)
      response.error = ResponseError.new("API Error: #{e}")

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

    def fetch_wsdl(url)
      key = "#{WSDL_NAMESPACE}/#{Digest::SHA256.hexdigest(url)}"
      cached = FreightKit.cache.read(key)
      return cached if cached

      response = HTTPClient.get(url)
      raise Wasabi::Resolver::HTTPError.new("Error: #{response.code} for url #{url}", response) unless (200..299).cover?(response.code)

      if WSDL_CACHE_HEADERS.none? { |field| response.headers.key?(field) }
        FreightKit.cache.write(key, response.body, expires_in: WSDL_EXPIRES_IN)
      end

      response.body
    end

    def savon_args
      args = client_args.merge(adapter: HTTPClient::HTTPIAdapter::NAME)
      args[:wsdl] = fetch_wsdl(args[:wsdl]) if args[:wsdl].to_s.match?(%r{\Ahttps?://})
      args
    end
  end
end
