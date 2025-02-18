# frozen_string_literal: true

module FreightKit
  class BTVP < TheGreatInformationFactory
    class << self
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

    include FreightKit::Documentable

    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Best Overnite Express'
    @@scac = 'BTVP'
  end
end
