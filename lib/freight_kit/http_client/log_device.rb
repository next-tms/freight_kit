# frozen_string_literal: true

module FreightKit
  class HTTPClient
    # HTTPX writes debug output to an IO-like object (#<<); this forwards it to a logger at debug level.
    class LogDevice
      def initialize(logger) = @logger = logger

      def <<(message)
        @logger.debug(message.chomp)
        self
      end
    end
  end
end
