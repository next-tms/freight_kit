# frozen_string_literal: true

module FreightKit
  module Error
    class Response < Base
      attr_reader :response

      def initialize(response = nil)
        if response.is_a?(Response)
          super(response.message)
          @response = response
        else
          super(response)
        end
      end
    end
  end
end
