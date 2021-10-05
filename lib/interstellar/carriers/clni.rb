# frozen_string_literal: true

module Interstellar
  class CLNI < CarrierLogistics
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Clear Lane Freight Systems'
    @@scac = 'CLNI'

    # Documents

    # Rates
    def build_calculated_accessorials(packages, origin, destination)
      accessorials = []

      longest_dimension = packages.inject([]) { |_arr, p| [p.length(:in), p.width(:in)] }.max.ceil
      if longest_dimension > 48
        if longest_dimension < 240
          accessorials << '&HHG=yes' # standard overlength fee
        elsif longest_dimension >= 240
          accessorials << '&OVER20=yes'
        elsif longest_dimension >= 192 && longest_dimension < 240
          accessorials << '&OVER16=yes'
        elsif longest_dimension >= 132 && longest_dimension < 192
          accessorials << '&OVER11=yes'
        elsif longest_dimension >= 96 && longest_dimension < 132
          accessorials << '&OVER11=yes'
        end
      end

      accessorials << '&BOSP=yes' if destination.city == 'Boston' && destination.state == 'MA'
      accessorials << '&BOSD=yes' if origin.city == 'Boston' && origin.state == 'MA'

      accessorials << '&SDDLY=yes' if destination.state == 'SD'
      accessorials << '&SDPU=yes' if origin.state == 'SD'

      # TODO: Add support for:
      # NYBDY, NYC BUROUGH DELY
      # NYBPU, NYC BUROUGH PU
      # NYLID, NYC LONG ISLAND DELY
      # NYLIP, NYC LONG ISLAND PU
      # NYMDY, NYC MANHATTAN DELY
      # NYMPU, NYC MANHATTAN PU
      # TXWDY, TXWST DELY
      # TXWPU, TXWST PU SURCHARGE

      accessorials
    end

    # Tracking

    # protected

    # Documents

    # Rates
  end
end
