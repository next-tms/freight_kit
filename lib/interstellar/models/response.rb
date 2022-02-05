# frozen_string_literal: true

module Interstellar
  # Basic Response class for requests against a carrier's API.
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
    attr_accessor :request, :response
  end
end
