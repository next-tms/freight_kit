# frozen_string_literal: true

module Interstellar
  class FCSY < CarrierLogistics
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Frontline Freight'
    @@scac = 'FCSY'

    # Documents

    # Rates
    def build_calculated_accessorials(*); end

    # Tracking

    # protected

    # Documents

    # Rates
  end
end
