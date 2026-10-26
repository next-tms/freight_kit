module FreightKit
  class HTTPClient
    # HTTPX plugin keeping connections open (HTTPX's persistent plugin) without risking duplicate
    # rates, pickups or tenders.
    #
    # The persistent plugin retries any request failing with a connection error, but a POST may
    # already have been processed by then, so only idempotent requests are retried.
    # Streams refused by an HTTP/2 GOAWAY are resent by HTTPX itself, independently of retries.
    module SafeRetries
      IDEMPOTENT_METHODS = ['DELETE', 'GET', 'HEAD', 'OPTIONS', 'PUT'].freeze

      module InstanceMethods
        private

        def retryable_request?(request, *) = super && IDEMPOTENT_METHODS.include?(request.verb)
      end

      class << self
        def load_dependencies(klass) = klass.plugin(:persistent)
      end
    end
  end
end
