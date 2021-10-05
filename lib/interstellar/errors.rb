module Interstellar
  class Error < ActiveUtils::ActiveUtilsError
  end

  class ResponseError < Interstellar::Error
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

  class ResponseContentError < Interstellar::Error
    def initialize(exception, content_body = nil)
      super([exception.message, content_body].compact.join(" \n\n"))
    end
  end

  class InvalidCredentialsError < Interstellar::ResponseError; end
  class ExpiredCredentialsError < Interstellar::InvalidCredentialsError; end

  class DocumentNotFound < Interstellar::Error; end
  class ShipmentNotFound < Interstellar::Error; end

  class USPSValidationError < StandardError; end

  class USPSMissingRequiredTagError < StandardError
    def initialize(tag, prop)
      super("Missing required tag #{tag} set by property #{prop}")
    end
  end
end
