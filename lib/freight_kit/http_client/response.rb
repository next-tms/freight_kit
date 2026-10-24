# frozen_string_literal: true

module FreightKit
  class HTTPClient
    # Like HTTParty::Response, unknown methods (e.g. #dig, #[]) are delegated to the parsed body.
    class Response
      JSON_CONTENT_TYPES = ['application/hal+json', 'application/json', 'application/vnd.api+json', 'text/json'].freeze
      XML_CONTENT_TYPES = ['application/xml', 'text/xml'].freeze

      attr_reader :body, :code, :content_type, :headers

      # Delegation alone would make empty bodies (parsed as nil) look present
      delegate :blank?, to: :parsed_response
      delegate_missing_to :parsed_response

      def initialize(response)
        @body = response.body.to_s
        @code = response.status
        @content_type = response.content_type.mime_type
        @headers = response.headers
      end

      def parsed_response
        return @parsed_response if defined?(@parsed_response)

        @parsed_response = if body.strip.empty? || body == 'null'
                             nil
                           elsif JSON_CONTENT_TYPES.include?(content_type)
                             JSON.parse(body, allow_nan: true)
                           elsif XML_CONTENT_TYPES.include?(content_type)
                             MultiXML.parse(body)
                           else
                             body
                           end
      end

      def to_s = body
    end
  end
end
