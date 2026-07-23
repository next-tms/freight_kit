# frozen_string_literal: true

module FreightKit
  class Tariff
    class OverlengthRule
      attr_reader :fee_cents, :max_length, :min_length

      def initialize(fee_cents:, max_length:, min_length:)
        raise ArgumentError, 'overlength_rule[:fee_cents] must be an Integer' unless fee_cents.is_a?(Integer)

        if max_length && !max_length.is_a?(Measured::Length)
          raise ArgumentError, 'overlength_rule[:max_length] must be one of Measured::Length, NilClass'
        end

        unless min_length.is_a?(Measured::Length)
          raise ArgumentError, 'overlength_rule[:min_length] must be a Measured::Length'
        end

        @fee_cents = fee_cents
        @max_length = max_length
        @min_length = min_length
      end

      # @param length [Measured::Length] a package's longest dimension.
      # @return [Boolean] whether this rule's length band covers the dimension.
      def cover?(length)
        return false if length < min_length

        max_length.nil? || length <= max_length
      end
    end
  end
end
