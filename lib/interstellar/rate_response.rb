module Interstellar

  # The `RateResponse` object is returned by the {Interstellar::Carrier#find_rates}
  # call. The most important method is {#rates}, which will return a list of possible
  # shipping options with an estimated price.
  #
  # @note Some carriers provide more information than others, so not all attributes
  #   will be set, depending on what carrier you are using.
  #
  # @!attribute rates
  #    The available rate options for the shipment, with an estimated price.
  #    @return [Array<Interstellar::RateEstimate>]
  class RateResponse < Response

    attr_reader :rates

    # Initializes a new RateResponse instance.
    #
    # @param success (see Interstellar::Response#initialize)
    # @param message (see Interstellar::Response#initialize)
    # @param params (see Interstellar::Response#initialize)
    # @option options (see Interstellar::Response#initialize)
    # @option options [Array<Interstellar::RateEstimate>] :rates The rate estimates to
    #   populate the {#rates} method with.
    def initialize(success, message, params = {}, options = {})
      @rates = Array(options[:estimates] || options[:rates] || options[:rate_estimates])
      super
    end

    alias_method :estimates, :rates
    alias_method :rate_estimates, :rates
  end
end
