# frozen_string_literal: true

module FreightKit
  module Error
    class HTTP < Base
      attr_reader :body, :code

      def initialize(body:, code:)
        @body = body
        @code = code

        super(message)
      end

      def message
        @message ||= ''.tap do |builder|
          builder << "HTTP #{@code}"
          builder << ":\n#{@body}" if @body.present?
        end
      end

      def to_hash
        @to_hash ||= { code: @http.code, headers: @http.headers, body: @http.body }
      end
    end
  end
end
