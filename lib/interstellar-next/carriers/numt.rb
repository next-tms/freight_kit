# frozen_string_literal: true

module Interstellar
  class NUMT < TheGreatInformationFactory
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Numark Transportation'
    @@scac = 'NUMT'

    def build_soap_header
      soap_header = super
      soap_header[:password] = soap_header[:password]&.downcase

      soap_header
    end

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(10_000, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(8, :feet)
    end
  end
end
