# frozen_string_literal: true

module FreightKit
  module Model
    # Basic Response class for requests against a carrier's API.
    #
    # @!attribute error
    #   The error object.
    #   @return [FreightKit::Error, NilClass]
    #
    # @!attribute request
    #   The raw request.
    #   @return [String]
    #
    # @!attribute response
    #   The raw response.
    #   @return [String]
    #
    class Response < Base
      attr_accessor :error, :request, :response
    end
  end
end
