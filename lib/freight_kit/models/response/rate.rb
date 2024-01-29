# frozen_string_literal: true

module FreightKit
  module Response
    # The `RateResponse` object is returned by the {FreightKit::Carrier#find_rates}
    # call. The most important method is {#rates}, which will return a list of possible
    # shipping options with an estimated price.
    #
    # @!attribute rates
    #    The available rate options for the shipment, with an estimated price.
    #    @return [Array<FreightKit::Rate>]
    #
    class Rate < Base
      attr_accessor :rates
    end
  end
end
