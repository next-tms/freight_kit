# frozen_string_literal: true

module Interstellar
  # Class representing a price.
  #
  # @!attribute blame
  #   Where did the cost come from?
  #   @return [Symbol] One of :api, :library, :tariff
  #
  # @!attribute description
  #   Description.
  #   @return [String]
  #
  # @!attribute objects
  #   Array of objects that the price applies to.
  #   @return [Array]
  #
  # @!attribute cents
  #   The price in cents.
  #   @return [Integer]
  #
  class Price < Model
    attr_accessor :description, :objects
    attr_writer :blame, :cents

    def initialize(attributes = {})
      assign_attributes(attributes)
    end

    def blame
      return @blame if %i[api library tariff].include?(@blame)

      raise 'blame must be one of :api, :library, :tariff'
    end

    def cents
      return @cents if @cents.is_a?(Integer)

      raise 'cents must be an `Integer`'
    end
  end
end
