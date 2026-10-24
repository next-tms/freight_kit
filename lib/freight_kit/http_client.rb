# frozen_string_literal: true

module FreightKit
  # Thin wrapper around HTTPX that negotiates Brotli/Zstandard compression, keeps connections
  # open between requests and revalidates cached responses with conditional requests (ETag/Last-Modified).
  #
  # The cache and logger are hookable; they default to the host Rails/Hanami app's logger:
  #
  #   FreightKit::HTTPClient.cache = Rails.cache
  #   FreightKit::HTTPClient.logger = Rails.logger
  class HTTPClient
    USER_AGENT = "freight_kit/#{VERSION} #{HTTPX::Options::USER_AGENT}".freeze

    @sessions = Concurrent::Map.new

    class << self
      def cache = @cache ||= ActiveSupport::Cache::MemoryStore.new

      def cache=(store)
        @cache = store
        @sessions.clear
      end

      def logger = @logger || framework_logger || ::Logger.new($stdout, level: ENV.fetch('LOG_LEVEL', 'info'))

      def logger=(logger)
        @logger = logger
        @sessions.clear
      end

      def get(url, **) = request(:get, url, **)

      def post(url, **) = request(:post, url, **)

      def request(verb, url, body: nil, headers: {}, proxy: nil, query: nil)
        options = { headers: }
        options[:params] = query if query.present?

        # Like HTTParty, hashes are form-encoded regardless of the Content-Type header
        if body.is_a?(Hash)
          options[:form] = body if body.present?
        elsif body.present?
          options[:body] = body
        end

        response = session(proxy.presence).request(verb.to_s.upcase, url, **options)
        raise response.error if response.is_a?(HTTPX::ErrorResponse)

        Response.new(response)
      end

      private

      def framework_logger
        if defined?(::Rails) && ::Rails.respond_to?(:logger)
          ::Rails.logger
        elsif defined?(::Hanami) && ::Hanami.respond_to?(:app?) && ::Hanami.app?
          ::Hanami.app['logger']
        end
      end

      # Sessions own their connection pool, so they are built once (per proxy) and reused
      def session(proxy)
        @sessions.compute_if_absent(proxy) do
          session = HTTPX
                    .plugin(:brotli)
                    .plugin(Zstd)
                    .plugin(:follow_redirects)
                    .plugin(:response_cache, response_cache_store: CacheStore.new(cache))
                    .plugin(Revalidation)
                    .plugin(SafeRetries)
                    .with(close_on_fork: true, headers: { 'user-agent' => USER_AGENT })

          logger = self.logger
          session = session.with(debug: LogDevice.new(logger), debug_level: 2) if logger.level <= ::Logger::DEBUG

          proxy ? session.plugin(:proxy).with(proxy: { uri: proxy }) : session
        end
      end
    end
  end
end
