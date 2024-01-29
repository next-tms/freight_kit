# frozen_string_literal: true

module FreightKit
  module Response
    # Represents the response to calls:
    #   - {FreightKit::Carrier#bol}
    #   - {FreightKit::Carrier#pod}
    #   - {FreightKit::Carrier#scanned_bol}
    #
    # @attribute content_type
    #   @return [String] The HTTP `Content-Type`
    #
    # @attribute data
    #   @return [String] Raw document data.
    class Document < Base
      attr_accessor :content_type, :data
    end
  end
end
