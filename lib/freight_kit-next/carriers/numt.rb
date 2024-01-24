# frozen_string_literal: true

module FreightKit
  class NUMT < TheGreatInformationFactory
    class << self
      def maximum_height
        Measured::Length.new(105, :inches)
      end

      def maximum_weight
        Measured::Weight.new(10_000, :pounds)
      end

      def minimum_length_for_overlength_fees
        Measured::Length.new(4, :ft)
      end

      def overlength_fees_require_tariff?
        false
      end

      def requirements
        %i[credentials]
      end
    end

    include FreightKit::Documentable

    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Numark Transportation'
    @@scac = 'NUMT'

    def build_calculated_accessorials(packages)
      longest_dimension = packages.map { |package| [package.length(:in), package.width(:in)].max }.max.ceil

      return ['OVER'] if longest_dimension > 48

      []
    end

    def build_soap_header
      soap_header = super
      soap_header[:password] = soap_header[:password]&.downcase

      soap_header
    end
  end
end
