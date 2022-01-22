# frozen_string_literal: true

module Interstellar
  # Class representing a shipping option with estimated price.
  #
  # @!attribute shipment
  #   The shipment
  #   @return [Interstellar::Shipment]
  #
  # @!attribute package_rates
  #   A list of rates for all the packages in the shipment
  #   @return [Array<{:rate => Integer, :package => Interstellar::Package}>]
  #
  # @!attribute carrier
  #   The carrier.
  #   @return [Interstellar::Carrier]
  #   @see Interstellar::Carrier
  #
  # @!attribute service_name
  #   The name of the shipping service (e.g. 'First Class Ground')
  #   @return [String]
  #
  # @!attribute service_code
  #   The code of the shipping service
  #   @return [String]
  #
  # @!attribute description
  #   Public description of the shipping service (e.g. '2 days delivery')
  #   @return [String]
  #
  # @!attribute shipping_date
  #   The date on which the shipment will be expected. Normally, this means that the
  #   delivery date range can only be promised if the shipment is handed over on or
  #   before this date.
  #   @return [Date]
  #
  # @!attribute delivery_date
  #   The date on which the shipment will be delivered. This is usually only available
  #   for express shipments; in other cases a {#delivery_range} is given instead.
  #   @return [Date]
  #
  # @!attribute delivery_range
  #   The minimum and maximum date of when the shipment is expected to be delivered
  #   @return [Array<Date>]
  #
  # @!attribute currency
  #   ISO4217 currency code of the quoted rate estimates (e.g. `CAD`, `EUR`, or `USD`)
  #   @return [String]
  #   @see http://en.wikipedia.org/wiki/ISO_4217
  #
  # @!attribute negotiated_rate
  #   The negotiated rate in cents
  #   @return [Integer]
  #
  # @!attribute compare_price
  #   The comparable price in cents
  #   @return [Integer]
  #
  # @!attribute phone_required
  #   Specifies if a phone number is required for the shipping rate
  #   @return [Boolean]
  #
  # @!attribute insurance_price
  #   The price of insurance in cents
  #   @return [Integer]
  #
  # @!attribute delivery_category
  #   The general classification of the delivery method
  #   @return [String]
  #
  # @!attribute shipment_options
  #   Additional priced options bundled with the given rate estimate with price in cents
  #   @return [Array<{ code: String, price: Integer }>]
  #
  # @!attribute charge_items
  #   Breakdown of a shipping rate's price with amounts in cents.
  #   @return [Array<{ group: String, code: String, name: String, description: String, amount: Integer }>]
  #
  # @!attribute scac
  #   SCAC code of the carrier. It may differ from the `Carrier` providing the quote when
  #   the `Carrier` is acting as a broker.
  #   @return [String]
  #
  class RateEstimate < Model
    attr_accessor :carrier, :charge_items, :compare_price, :declared_value_cents, :delivery_category, :delivery_date,
                  :description, :estimate_reference, :expires_at, :insurance_price, :messages, :negotiated_rate,
                  :package_rates, :phone_required, :pickup_time, :scac, :service_code, :service_name, :shipment,
                  :shipment_options, :shipping_date, :transit_days, :with_excessive_length_fees

    attr_writer :currency, :delivery_range, :total_price

    def initialize(attributes = {})
      assign_attributes(attributes)
      super
    end

    # The total price of the shipments in cents.
    # @return [Integer]
    def total_price
      @total_price || @package_rates.sum { |pr| pr[:rate] }
    rescue NoMethodError
      raise ArgumentError, 'RateEstimate must have a total_price set, or have a full set of valid package rates.'
    end
    alias price total_price

    # Adds a package to this rate estimate
    # @param package [Interstellar::Package] The package to add.
    # @param rate [#cents, Float, String, nil] The rate for this package. This is only required if
    #   there is no total price for this shipment
    # @return [self]
    def add(package, rate = nil)
      cents = Package.cents_from(rate)
      if cents.nil? && total_price.nil?
        raise ArgumentError,
              'New packages must have valid rate information since this RateEstimate has no total_price set.'
      end

      @package_rates << { package:, rate: cents }
      self
    end

    # The list of packages for which rate estimates are given.
    # @return [Array<Interstellar::Package>]
    def packages
      package_rates.map { |p| p[:package] }
    end

    # The number of packages for which rate estimates are given.
    # @return [Integer]
    def package_count
      package_rates.length
    end

    protected

    def delivery_range
      @delivery_range = delivery_range ? delivery_range.map { |date| date_for(date) }.compact : []
    end

    def currency
      ActiveUtils::CurrencyCode.standardize(currency)
    end

    private

    # Returns a Date object for a given input
    # @param date [String, Date, Time, DateTime, ...] The object to infer a date from.
    # @return [Date, nil] The Date object absed on the input, or `nil` if no date
    #   could be determined.
    def date_for(date)
      date && Date.strptime(date.to_s, '%Y-%m-%d')
    rescue ArgumentError
      nil
    end
  end
end
