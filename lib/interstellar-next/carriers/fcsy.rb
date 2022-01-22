# frozen_string_literal: true

module Interstellar
  class FCSY < CarrierLogistics
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Frontline Freight'
    @@scac = 'FCSY'

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(10_000, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(12, :feet)
    end

    def overlength_fees_require_tariff?
      true
    end

    # Documents

    # Rates
    def build_calculated_accessorials(*); end

    # Tracking

    # protected

    # Documents

    # Rates
  end
end
