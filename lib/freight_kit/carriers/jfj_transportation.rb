# frozen_string_literal: true

module FreightKit
  class JFJTransportation < Next
    REACTIVE_FREIGHT_CARRIER = true

    class << self
      attr_reader :name, :scac
    end
    @name = 'JFJ Transportation'
    @scac = nil
  end
end
