module FreightKit
  # Carrier is the abstract base class for all supported carriers.
  #
  # To implement support for a carrier, you should subclass this class and
  # implement all the methods that the carrier supports.
  #
  # @see #create_pickup
  # @see #find_tracking_info
  # @see #find_rates
  #
  # @!attribute last_request
  #   The last request performed against the carrier's API.
  #   @see #save_request
  class Carrier
    class << self
      # Whether the carrier is a broker that hands shipments to other carriers.
      # @return [Boolean]
      def acts_as_broker? = false

      # Whether bill of lading (BOL) requires tracking number at time of pickup.
      # @return [Boolean]
      def bol_requires_tracking_number? = false

      # The carrier's addresses for mailing checks, so applications need not enter them for each customer.
      # @return [Array<FreightKit::Address>]
      def check_mailing_addresses = []

      # Whether the carrier's bill of lading (BOL) and proof of delivery (POD) are the same document.
      # @return [Boolean]
      def consider_bol_and_pod_documents_same? = false

      # The carrier's department contacts, so applications need not enter them for each customer.
      # @return [Array<FreightKit::Contact>]
      def contacts = []

      # Whether {#create_pickup} is implemented.
      # @return [Boolean]
      def create_pickup_implemented? = implemented?(:create_pickup)

      # Whether {#find_rates} is implemented.
      # @return [Boolean]
      def find_rates_implemented? = implemented?(:find_rates)

      # Whether finding rates with declared value (thus insurance) is implemented.
      # @return [Boolean]
      def find_rates_with_declared_value? = false

      # The carrier's main office, from its public FMCSA registration.
      # @return [FreightKit::Address, nil]
      def headquarters = nil

      # The carrier's permanent UUID. Applications store it to refer to the carrier, so never change or reuse one.
      # @return [String]
      def id = nil

      # Whether instance method is supported
      # @return [Boolean]
      def implemented?(instance_method)
        instance_method(instance_method).owner != FreightKit::Carrier
      rescue NameError
        false
      end

      # The carrier's registered legal name, with its entity suffix (e.g. "Saia Motor Freight Line LLC"), when known.
      # {.name} is the name the carrier does business as.
      # @return [String, nil]
      def legal_name = nil

      # The package's longest horizontal dimension (length or width), as a
      # Measured::Length so comparisons stay unit-agnostic.
      #
      # @param package [FreightKit::Package]
      # @return [Measured::Length]
      def longest_dimension(package)
        [
          Measured::Length.new(package.length(:inches), :inches),
          Measured::Length.new(package.width(:inches), :inches)
        ].max
      end

      # FreightKit accessorials the carrier prices, mapped to the carrier's codes.
      # @return [Hash{Symbol => Object}]
      def mappable_accessorials = {}

      # The maximum height the carrier will accept.
      # @return [Measured::Length]
      def maximum_height = Measured::Length.new(105, :inches)

      # The maximum weight the carrier will accept.
      # @return [Measured::Weight]
      def maximum_weight = Measured::Weight.new(10_000, :pounds)

      # What length overlength fees the carrier begins charging at.
      # @return [Measured::Length]
      def minimum_length_for_overlength_fees = Measured::Length.new(48, :inches)

      # @param package [FreightKit::Package]
      # @return [Boolean] whether the package is long enough to incur overlength fees.
      def overlength?(package) = longest_dimension(package) >= minimum_length_for_overlength_fees

      def overlength_fee(tariff, package)
        overlength_rule = overlength_rule_for(tariff, package)
        return 0 if overlength_rule.nil?

        package.quantity * overlength_rule.fee_cents
      end

      # Whether or not the carrier quotes overlength fees via API.
      # @note Should the API not calculate these fees, they should be calculated some other way outside of FreightKit.
      # @return [Boolean]
      def overlength_fees_require_tariff? = true

      # Returns the overlength rule from +tariff+ that applies to +package+, or
      # +nil+ when the package is not overlength, or no configured rule covers it.
      #
      # This is the single source of truth for "does a rule cover this package?"
      # shared by {#overlength_fee} and {#validate_packages} so the two can never
      # disagree (e.g. a package quoting $0 overlength while also being treated as
      # serviceable).
      #
      # @param tariff [FreightKit::Tariff, nil]
      # @param package [FreightKit::Package]
      # @return [FreightKit::Tariff::OverlengthRule, nil]
      def overlength_rule_for(tariff, package)
        return unless tariff.is_a?(FreightKit::Tariff) && overlength?(package)

        tariff.overlength_rules.find { |overlength_rule| overlength_rule.cover?(longest_dimension(package)) }
      end

      # Whether carrier considers pickup number the same as the tracking number.
      def pickup_number_is_tracking_number? = false

      # Whether the rates the carrier's API returns include excessive length fees. Carriers without rates, or that need
      # a tariff to price overlength fees, return rates without them.
      # @return [Boolean]
      def rates_with_excessive_length_fees? = find_rates_implemented? && requirements.exclude?(:tariff)

      # Returns the `Credential` methods (passed to `#initialize`) that cannot respond with blank values.
      # @return [Array<Symbol>]
      def required_credential_types = []

      # Returns the keywords passed to `#initialize` that cannot be blank.
      # @return [Array<Symbol>]
      def requirements = []

      # @return [String, nil]
      def scac = nil

      # Raises {UnserviceableAccessorialsError} for accessorials the carrier refuses, or that it neither maps nor serves
      # unpriced. Returns false when the carrier maps no accessorials.
      # @return [Boolean]
      def serviceable_accessorials?(accessorials)
        return true if accessorials.blank?
        return false if mappable_accessorials.blank?

        refused = accessorials.select do |accessorial|
          unserviceable_accessorials.include?(accessorial) ||
            (mappable_accessorials.keys.exclude?(accessorial) && unquotable_accessorials.exclude?(accessorial))
        end
        raise FreightKit::UnserviceableAccessorialsError.new(accessorials: refused) if refused.any?

        true
      end

      # The services {#find_rates} quotes (e.g. `:standard`, `:guaranteed_delivery`).
      # @return [Array<Symbol>]
      def services = []

      # The carrier's terminals, so applications need not enter them for each customer.
      # @return [Array<FreightKit::Terminal>]
      def terminals = []

      # The template URL for tracking one of carrier's `NUMBERS` publicly. A template URL is a URL containing the token
      # "%s" that can be replaced to generate a valid URL.
      #
      # This method is designed to provide a template URL for a specific tracking-related key, allowing applications to
      # generate valid tracking URLs without involving FreightKit each time. The `key` parameter must be one of the
      # predefined carrier number types specified in the `NUMBERS` constant.
      #
      # @see `NUMBERS`
      # @param [Symbol] key The symbol representing the type of tracking information for which the template URL is
      # needed.
      # @raise [ArgumentError]
      # @return [String, nil] The template URL or nil if no template is available for the given key.
      def tracking_url_template(key)
        raise ArgumentError, "key must be one of: #{NUMBERS.join(', ')}" if NUMBERS.exclude?(key)

        tracking_url_templates[key]
      end

      # The template URLs for {.tracking_url_template}, by `NUMBERS` key.
      # @return [Hash{Symbol => String}]
      def tracking_url_templates = {}

      # FreightKit accessorials the carrier serves but does not price.
      # @return [Array<Symbol>]
      def unquotable_accessorials = []

      # FreightKit accessorials the carrier refuses.
      # @return [Array<Symbol>]
      def unserviceable_accessorials = []

      # @return [Integer, nil]
      def us_dot_number = nil

      # @return [Integer, nil]
      def us_mc_number = nil

      # Regular expression to use for validating carrier's `NUMBERS`.
      #
      # Returns the regular expression used for validating the carrier's number based on the provided `key`.
      # The `key` parameter must be one of the predefined carrier number types specified in the `NUMBERS` constant.
      #
      # @see `NUMBERS`
      # @param [Symbol] key The symbol representing the carrier number type for which the regular expression is needed.
      # @raise [ArgumentError] Raised if the provided key is not one of the specified carrier number types.
      # @return [Regexp, nil] The regular expression for validating the specified carrier number type.
      def valid_number_regex(key)
        raise ArgumentError, "key must be one of: #{NUMBERS.join(', ')}" if NUMBERS.exclude?(key)

        valid_number_regexes[key]
      end

      # The regular expressions for {.valid_number_regex}, by `NUMBERS` key.
      # @return [Hash{Symbol => Regexp}]
      def valid_number_regexes = {}

      # Determine whether the carrier will accept the packages based on credentials and/or tariff.
      # @param packages [Array<FreightKit::Package>]
      # @param tariff [FreightKit::Tariff]
      # @return [Boolean]
      def validate_packages(packages, tariff = nil)
        return false if packages.blank?

        message = []

        max_height_inches = maximum_height.convert_to(:inches).value
        if packages.map { |p| p.height(:inches) }.max > max_height_inches
          message << "items must be #{max_height_inches.to_f} inches tall or less"
        end

        max_weight_pounds = maximum_weight.convert_to(:pounds).value
        message << "items must weigh #{max_weight_pounds.to_f} lbs or less" if packages.sum { |p| p.pounds(:total) } > max_weight_pounds

        # Carriers that don't quote overlength fees via their API rely on the
        # tariff to price them. Fail closed rather than silently under-quoting: a
        # missing, empty, or non-covering tariff for an overlength package must
        # make the carrier unserviceable. We key off rule *coverage* (via
        # #overlength_rule_for) rather than the tariff object's mere presence,
        # because a present-but-empty FreightKit::Tariff is not `blank?` and would
        # otherwise slip past this check.
        if overlength_fees_require_tariff?
          missing_dimensions = packages.any? do |package|
            [package.height(:inches), package.length(:inches), package.width(:inches)].any?(&:zero?)
          end

          uncovered_overlength = packages.any? do |package|
            overlength?(package) && overlength_rule_for(tariff, package).nil?
          end

          if missing_dimensions
            message << 'item dimensions are required'
          elsif uncovered_overlength
            message << 'tariff must be defined to calculate overlength fees'
          end
        end

        raise UnserviceableError, message.join(', ').capitalize if message.present?

        true
      end

      # The carrier's homepage, verified to load over HTTPS and to name the carrier (e.g. "https://abf.com").
      # @return [String, nil]
      def website_url = nil
    end

    NUMBERS = %i[bol_number order_number pickup_number po_number tracking_number].freeze

    attr_reader :credentials, :customer_location, :last_request, :tariff

    delegate :id,
             :longest_dimension,
             :mappable_accessorials,
             :name,
             :overlength?,
             :overlength_fee,
             :overlength_rule_for,
             :rates_with_excessive_length_fees?,
             :scac,
             :serviceable_accessorials?,
             :unquotable_accessorials,
             :unserviceable_accessorials,
             :valid_number_regex,
             :validate_packages,
             to: :class

    # @param credentials [Array<Credential>]
    # @param customer_location [Location]
    # @param tariff [Tariff]
    def initialize(credentials, customer_location: nil, tariff: nil)
      credentials = [credentials] if credentials.is_a?(Credential)

      if credentials.map(&:class).uniq != [Credential]
        message = "#{name}#new: `credentials` must be a Credential or Array of Credential"
        raise ArgumentError, message
      end

      missing_credential_types = self.class.required_credential_types.uniq - credentials.map(&:type).uniq

      if missing_credential_types.any?
        message = "#{name}#new: `Credential` of type(s) missing: #{missing_credential_types.join(', ')}"
        raise ArgumentError, message
      end

      @credentials = credentials

      if customer_location.present?
        unless customer_location.is_a?(Location)
          message = "#{name}#new: `customer_location` must be a Location"
          raise ArgumentError, message
        end

        @customer_location = customer_location
      end

      return if tariff.blank?
      raise ArgumentError, "#{name}#new: `tariff` must be a Tariff" unless tariff.is_a?(Tariff)

      @tariff = tariff
    end

    # Asks the carrier for the bill of lading that the carrier would provide before shipping.
    #
    # @see #scanned_bol
    #
    # @param [String] tracking_number Tracking number.
    # @return [DocumentResponse]
    def bol(tracking_number) = raise NotImplementedError, "#{name}: #bol not supported"

    # Registers a new pickup with the carrier, to get a tracking number and
    # potentially shipping labels
    #
    # @note Override with whatever you need to register a shipment, and obtain
    #   shipping labels if supported by the carrier.
    #
    # @param delivery_from [ActiveSupport::TimeWithZone] Local date, time and time zone that
    #   delivery hours begin.
    # @param delivery_to [ActiveSupport::TimeWithZone] Local date, time and time zone that
    #   delivery hours end.
    # @param dispatcher [FreightKit::Contact] The dispatcher.
    # @param pickup_from [ActiveSupport::TimeWithZone] Local date, time and time zone that
    #   pickup hours begin.
    # @param pickup_to [ActiveSupport::TimeWithZone] Local date, time and time zone that
    #   pickup hours end.
    # @param scac [String] The carrier SCAC code (can be `nil`; only used for brokers).
    # @param service [Symbol] The service type.
    # @param shipment [FreightKit::Shipment] The shipment including `#destination.contact`, `#origin.contact`.
    # @return [FreightKit::ShipmentResponse] The response from the carrier. This
    #   response should include a shipment identifier or tracking_number if successful,
    #   and potentially shipping labels.
    def create_pickup(
      delivery_from:,
      delivery_to:,
      dispatcher:,
      pickup_from:,
      pickup_to:,
      scac:,
      service:,
      shipment:
    )
      raise NotImplementedError, "#create_pickup is not supported by #{name}."
    end

    # Fetch credential of given type.
    #
    # @param type [Symbol] Type of credential to find, should be one of: `:api`, `:selenoid`, `:website`.
    # @return [FreightKit::Credential|NilClass]
    def fetch_credential(type) = credentials.find { |credential| credential.type == type }

    # Asks the carrier for a list of locations (terminals) for a given country
    #
    # @param [ActiveUtils::Country] country
    # @return [Array<Location>]
    def find_locations(country) = raise NotImplementedError, "#{name}: #find_locations not supported"

    # Asks the carrier for rate estimates for a given shipment.
    #
    # @note Override with whatever you need to get the rates from the carrier.
    #
    # @param shipment [FreightKit::Shipment] Shipment details.
    # @return [FreightKit::RateResponse] The response from the carrier, which
    #   includes 0 or more rate estimates for different shipping products
    def find_rates(shipment:) = raise NotImplementedError, "#find_rates is not supported by #{name}."

    # Retrieves tracking information for a previous shipment
    #
    # @note Override with whatever you need to get a shipping label
    #
    # @param tracking_number [String] The tracking number of the shipment to track.
    # @return [FreightKit::TrackingResponse] The response from the carrier. This
    #   response should a list of shipment tracking events if successful.
    def find_tracking_info(tracking_number)
      raise NotImplementedError, "#find_tracking_info is not supported by #{name}."
    end

    def find_tracking_number_from_pickup_number(pickup_number, date)
      raise NotImplementedError, "#{name}: #find_tracking_number_from_pickup_number not supported"
    end

    # Asks the carrier for the scanned proof of delivery that the carrier would provide after delivery.
    #
    # @param [String] tracking_number Tracking number.
    # @return [DocumentResponse]
    def pod(tracking_number) = raise NotImplementedError, "#{name}: #pod not supported"

    # Asks the carrier for the scanned bill of lading that the carrier would provide after shipping.
    #
    # @see #bol
    #
    # @param [String] tracking_number Tracking number.
    # @return [DocumentResponse]
    def scanned_bol(tracking_number) = raise NotImplementedError, "#{name}: #scanned_bol not supported"

    # Validate the tracking number (may call API).
    #
    # @param [String] tracking_number Tracking number.
    # @return [Boolean] Should return `true` if the provided pro is valid.
    def valid_tracking_number?(tracking_number)
      raise NotImplementedError, "#valid_tracking_number? is not supported by #{name}."
    end

    protected

    # Use after building the request to save for later inspection.
    # @return [void]
    def save_request(request) = @last_request = request

    # Calculates a timestamp that corresponds a given number of business days in the future
    #
    # @param days [Integer] The number of business days from now.
    # @return [Time] A timestamp, the provided number of business days in the future.
    def timestamp_from_business_day(days)
      raise ArgumentError, 'days must be an Integer' unless days.is_a?(Integer)

      date = Time.current.utc + days.days

      date += 2.days if date.saturday?
      date += 1.day if date.sunday?

      date
    end
  end
end
