module FreightKit
  class HTTPClient
    # HTTPI adapter sending Savon's requests through {HTTPClient}, so SOAP calls get its compression,
    # connection reuse, retries, cache, logger and User-Agent:
    #
    #   Savon.client(adapter: FreightKit::HTTPClient::HTTPIAdapter::NAME, wsdl: url)
    class HTTPIAdapter < HTTPI::Adapter::Base
      NAME = :freight_kit

      register NAME

      attr_reader :client

      def initialize(request)
        super
        raise HTTPI::NotSupportedError, "#{NAME} does not support #{request.auth.type} authentication" if request.auth.type

        @client = HTTPClient
        @request = request
      end

      def request(method)
        response = client.request(
          method,
          @request.url.to_s,
          body: @request.body,
          headers: @request.headers.to_h,
          proxy_url: @request.proxy&.to_s,
          read_timeout: @request.read_timeout
        )

        # HTTPX already decoded the body, and HTTPI would gunzip it again
        HTTPI::Response.new(response.code, response.headers.to_h.except('content-encoding'), response.body)
      end
    end
  end
end
