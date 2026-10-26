module FreightKit
  class HTTPClient
    # Adapts an ActiveSupport::Cache::Store-like backend (#read, #write, #delete_matched)
    # to the HTTPX cache store interface (#get, #set, #clear).
    #
    # HTTPX responses hold sockets and options, so only status, headers and body are stored.
    class CacheStore
      NAMESPACE = 'freight_kit/http_client'.freeze
      VALIDATOR_HEADERS = ['if-modified-since', 'if-none-match'].freeze

      def initialize(backend) = @backend = backend

      # RedisCacheStore only supports glob strings, the other ActiveSupport stores only regular expressions
      def clear
        @backend.delete_matched(%r{\A#{Regexp.escape(NAMESPACE)}/})
      rescue ArgumentError
        @backend.delete_matched("#{NAMESPACE}/*")
      end

      def get(request)
        entry = @backend.read(key(request))
        return if entry.blank?

        response = request.options.response_class.new(request, entry[:status], entry[:version], entry[:headers])
        response.finish!
        response.mark_as_cached!
        response.body.write(entry[:body])
        response.body.rewind
        response
      end

      def set(request, response)
        response.body.rewind

        @backend.write(
          key(request),
          {
            body: response.body.to_s,
            headers: response.headers.to_h,
            status: response.status,
            version: response.version
          }
        )
      end

      private

      # Unlike HTTPX's default key, every request header (e.g. Authorization, API keys) is
      # part of the key so that responses are never shared across credentials.
      # Query parameters given as `params:` are only part of the request path, not its URI.
      def key(request)
        headers = request.headers.to_a.reject { |field, _| VALIDATOR_HEADERS.include?(field) }.sort
        digest = Digest::SHA256.hexdigest([request.verb, request.uri.merge(request.path).to_s, headers].to_json)

        "#{NAMESPACE}/#{digest}"
      end
    end
  end
end
