# frozen_string_literal: true

module Interstellar
  # The `RateResponse` object is returned by the {Interstellar::Carrier#find_rates}
  # call. The most important method is {#rates}, which will return a list of possible
  # shipping options with an estimated price.
  #
  # @!attribute rates
  #    The available rate options for the shipment, with an estimated price.
  #    @return [Array<Interstellar::Rate>]
  #
  class RateResponse < Response
    attr_accessor :rates
  end
end
