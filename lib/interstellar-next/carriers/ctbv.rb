# frozen_string_literal: true

module Interstellar
  class CTBV < CarrierLogistics
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'The Custom Companies'
    @@scac = 'CTBV'

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(10_000, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(8, :feet)
    end

    def overlength_fees_require_tariff?
      false
    end

    # Documents

    # Rates
    def build_calculated_accessorials(packages, *)
      accessorials = []

      longest_dimension = packages.inject([]) { |_arr, p| [p.length(:in), p.width(:in)] }.max.ceil
      if longest_dimension > 144
        accessorials << '&OL=yes'
      elsif longest_dimension >= 96 && longest_dimension <= 144
        accessorials << '&OL1=yes'
      end

      accessorials
    end

    # Tracking

    # protected

    # Documents

    # Rates
  end
end
