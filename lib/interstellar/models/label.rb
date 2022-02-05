# frozen_string_literal: true

module Interstellar
  # Class representing a shipping option with estimated price.
  #
  # @!attribute data
  #   The label image data.
  #   @return [String]
  #
  class Label < Model
    attr_accessor :data
  end
end
