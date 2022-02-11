# frozen_string_literal: true

module Interstellar
  # Basic Response class for requests against a carrier's API.
  #
  # @!attribute error
  #   The error object.
  #   @return [Interstellar::Error, NilClass]
  #
  # @!attribute request
  #   The raw request.
  #   @return [String]
  #
  # @!attribute response
  #   The raw response.
  #   @return [String]
  #
  class Response < Model
    attr_accessor :error, :request, :response
  end
end
