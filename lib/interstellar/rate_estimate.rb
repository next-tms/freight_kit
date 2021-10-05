module Interstellar

  # Class representing a shipping option with estimated price.
  #
  # @!attribute origin
  #   The origin of the shipment
  #   @return [Interstellar::Location]
  #
  # @!attribute destination
  #   The destination of the shipment
  #   @return [Interstellar::Location]
  #
  # @!attribute package_rates
  #   A list of rates for all the packages in the shipment
  #   @return [Array<{:rate => Integer, :package => Interstellar::Package}>]
  #
  # @!attribute carrier
  #   The name of the carrier (e.g. 'USPS', 'FedEx')
  #   @return [String]
  #   @see Interstellar::Carrier.name
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
  class RateEstimate
    attr_accessor :carrier, :charge_items, :compare_price, :currency,
                  :delivery_category, :delivery_date, :delivery_range,
                  :description, :destination, :estimate_reference, :expires_at,
                  :insurance_price, :messages, :negotiated_rate, :origin,
                  :package_rates, :phone_required, :pickup_time, :service_code,
                  :service_name, :shipment_options, :shipping_date, :transit_days,
                  :with_excessive_length_fees

    def initialize(origin, destination, carrier, service_name, options = {})
      self.charge_items = options[:charge_items] || []
      self.compare_price = options[:compare_price]
      self.currency = options[:currency]
      self.delivery_category = options[:delivery_category]
      self.delivery_range = options[:delivery_range]
      self.description = options[:description]
      self.estimate_reference = options[:estimate_reference]
      self.expires_at = options[:expires_at]
      self.insurance_price = options[:insurance_price]
      self.messages = options[:messages] || []
      self.negotiated_rate = options[:negotiated_rate]
      self.origin = origin
      self.destination = destination
      self.carrier = carrier
      self.service_name = service_name
      self.package_rates = if options[:package_rates]
                             options[:package_rates].map { |p| p.update(rate: Package.cents_from(p[:rate])) }
                           else
                             Array(options[:packages]).map { |p| { package: p } }
                           end
      self.phone_required = options[:phone_required]
      self.pickup_time = options[:pickup_time]
      self.service_code = options[:service_code]
      self.shipment_options = options[:shipment_options] || []
      self.shipping_date = options[:shipping_date]
      self.transit_days = options[:transit_days]
      self.total_price = options[:total_price]
      self.with_excessive_length_fees = options.dig(:with_excessive_length_fees)

      self.delivery_date = @delivery_range.last
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
        raise ArgumentError, 'New packages must have valid rate information since this RateEstimate has no total_price set.'
      end

      @package_rates << { package: package, rate: cents }
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

    def delivery_range=(delivery_range)
      @delivery_range = delivery_range ? delivery_range.map { |date| date_for(date) }.compact : []
    end

    def total_price=(total_price)
      @total_price = Package.cents_from(total_price)
    end

    def negotiated_rate=(negotiated_rate)
      @negotiated_rate = negotiated_rate ? Package.cents_from(negotiated_rate) : nil
    end

    def compare_price=(compare_price)
      @compare_price = compare_price ? Package.cents_from(compare_price) : nil
    end

    def currency=(currency)
      @currency = ActiveUtils::CurrencyCode.standardize(currency)
    end

    def phone_required=(phone_required)
      @phone_required = !!phone_required
    end

    def shipping_date=(shipping_date)
      @shipping_date = date_for(shipping_date)
    end

    def insurance_price=(insurance_price)
      @insurance_price = Package.cents_from(insurance_price)
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
