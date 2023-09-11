# frozen_string_literal: true

module FreightKit
  module Model
    # Class representing a shipping option with estimated price.
    #
    # @!attribute data
    #   The label image data.
    #   @return [String]
    #
    class Label < Base
      attr_accessor :data
    end
  end
end
