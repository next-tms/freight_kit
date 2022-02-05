# frozen_string_literal: true

module Interstellar
  # The `PickupResponse` object is returned by the {Interstellar::Carrier#create_pickup}
  # call. The most important method is {#pickup_number}, which will return the pickup reference
  # number.
  #
  # @!attribute pickup_number
  #    Pickup reference number.
  #    @return [String]
  #
  class PickupResponse < Response
    attr_reader :pickup_number
  end
end
