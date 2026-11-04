module FreightKit
  class HTTPClient
    # HTTPX plugin keeping connections open (HTTPX's persistent plugin) without risking duplicate
    # rates, pickups or tenders.
    #
    # The persistent plugin retries any request failing with a connection error, but a POST may
    # already have been processed by then, so only idempotent requests are retried.
    # Streams refused by an HTTP/2 GOAWAY are resent by HTTPX itself, independently of retries.
    #
    # A 429 means the server did not process the request, so any request is retried once after its
    # Retry-After seconds, unless that is longer than {MAX_RETRY_AFTER}.
    module SafeRetries
      IDEMPOTENT_METHODS = ['DELETE', 'GET', 'HEAD', 'OPTIONS', 'PUT'].freeze
      # Longest wait in seconds. Longer waits return the 429, so callers can reschedule instead of blocking.
      MAX_RETRY_AFTER = 60

      module InstanceMethods
        private

        def rate_limited?(response)
          response.is_a?(HTTPX::Response) && response.status == 429 && retry_after(response)&.between?(0, MAX_RETRY_AFTER)
        end

        def retry_after(response) = Integer(response.headers['retry-after'], 10, exception: false)

        def retryable_request?(request, response, *)
          rate_limited?(response) || (super && IDEMPOTENT_METHODS.include?(request.verb))
        end

        def retryable_response?(response, *) = super || rate_limited?(response)
        def when_to_retry(request, response, *) = rate_limited?(response) ? retry_after(response) : super
      end

      class << self
        def load_dependencies(klass) = klass.plugin(:persistent)
      end
    end
  end
end
