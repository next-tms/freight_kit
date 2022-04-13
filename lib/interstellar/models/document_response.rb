# frozen_string_literal: true

module Interstellar
  # Represents the response to calls:
  #   - {Interstellar::Carrier#bol}
  #   - {Interstellar::Carrier#pod}
  #   - {Interstellar::Carrier#scanned_bol}
  #
  # @attribute content_type
  #   @return [String] The HTTP `Content-Type`
  #
  # @attribute data
  #   @return [String] Raw document data.
  class DocumentResponse < Response
    attr_accessor :content_type, :data
  end
end
