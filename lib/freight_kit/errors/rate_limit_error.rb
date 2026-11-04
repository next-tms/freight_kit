module FreightKit
  # The API refused a request because the caller sent too many. Wait {#retry_after} seconds before the next one.
  class RateLimitError < HTTPError
    attr_reader :retry_after

    def initialize(body:, code:, retry_after: nil)
      @retry_after = retry_after

      super(body:, code:)
    end
  end
end
