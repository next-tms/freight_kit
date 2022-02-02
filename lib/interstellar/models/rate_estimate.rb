# frozen_string_literal: true

module Interstellar
  # Class representing a shipping option with estimated price.
  #
  # @!attribute carrier
  #   The carrier.
  #   @return [Interstellar::Carrier]
  #   @see Interstellar::Carrier
  #
  # @!attribute carrier_name
  #   Name of the carrier. It may differ from the `Carrier` providing the rate quote
  #   when the `Carrier` is acting as a broker.
  #   @return [String]
  #
  # @!attribute currency
  #   ISO4217 currency code of the quoted rate estimates (e.g. `CAD`, `EUR`, or `USD`)
  #   @return [String]
  #   @see http://en.wikipedia.org/wiki/ISO_4217
  #
  # @!attribute estimate_reference
  #   Quote number.
  #   @return [String]
  #
  # @!attribute expires_at
  #   When the rate estimate will expire.
  #   @return [DateTime]
  #
  # @!attribute prices
  #   Breakdown of a rate estimate's prices with amounts in cents.
  #   @return [Array<Prices>]
  #   @see Interstellar::Price
  #
  # @!attribute scac
  #   SCAC code of the carrier. It may differ from the `Carrier` providing the rate
  #   estimate when the `Carrier` is acting as a broker.
  #   @return [String]
  #
  # @!attribute service_name
  #   The name of the shipping service (e.g. 'First Class Ground')
  #   @return [String]
  #
  # @!attribute shipment
  #   The shipment.
  #   @return [Interstellar::Shipment]
  #
  # @!attribute transit_days
  #   Estimated transit days after date of pickup.
  #   @return [Integer]
  #
  # @!attribute with_excessive_length_fees
  #   When the rate estimate `Price`s include applicable excessive length fees.
  #   @return [Integer]
  #
  class RateEstimate < Model
    attr_accessor :carrier,
                  :carrier_name,
                  :estimate_reference,
                  :expires_at,
                  :prices,
                  :scac,
                  :service_name,
                  :shipment,
                  :transit_days,
                  :with_excessive_length_fees

    attr_writer :currency

    def initialize(attributes = {})
      assign_attributes(attributes)
    end

    def currency
      ActiveUtils::CurrencyCode.standardize(@currency)
    end

    # The total price of the shipment in cents.
    # @return [Integer]
    def total_cents
      return 0 if @prices.blank?

      @prices.sum(&:cents)
    end
  end
end
