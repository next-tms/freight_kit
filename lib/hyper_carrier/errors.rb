module HyperCarrier
  class Error < ActiveUtils::ActiveUtilsError
  end

  class ResponseError < HyperCarrier::Error
    attr_reader :response

    def initialize(response = nil)
      if response.is_a? Response
        super(response.message)
        @response = response
      else
        super(response)
      end
    end
  end

  class ResponseContentError < HyperCarrier::Error
    def initialize(exception, content_body = nil)
      super([exception.message, content_body].compact.join(" \n\n"))
    end
  end

  class InvalidCredentialsError < HyperCarrier::ResponseError; end

  class DocumentNotFound < HyperCarrier::Error; end
  class ShipmentNotFound < HyperCarrier::Error; end

  class USPSValidationError < StandardError; end

  class USPSMissingRequiredTagError < StandardError
    def initialize(tag, prop)
      super("Missing required tag #{tag} set by property #{prop}")
    end
  end
end
