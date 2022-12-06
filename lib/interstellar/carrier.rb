# frozen_string_literal: true

module Interstellar
  # Carrier is the abstract base class for all supported carriers.
  #
  # To implement support for a carrier, you should subclass this class and
  # implement all the methods that the carrier supports.
  #
  # @see #create_pickup
  # @see #cancel_shipment
  # @see #find_tracking_info
  # @see #find_rates
  #
  # @!attribute last_request
  #   The last request performed against the carrier's API.
  #   @see #save_request
  class Carrier
    class << self
      # Whether looking up available services is implemented.
      # @return [Boolean]
      def available_services_implemented?
        false
      end

      # Whether bill of lading (BOL) requires tracking number at time of pickup.
      # @return [Boolean]
      def bol_requires_tracking_number?
        false
      end

      # Whether canceling a shipment is implemented.
      # @return [Boolean]
      def cancel_shipment_implemented?
        false
      end

      # Whether creating a pickup is implemented.
      # @return [Boolean]
      def create_pickup_implemented?
        false
      end

      # The default location to use for {#valid_credentials?}.
      # @return [Interstellar::Location]
      def default_location
        Location.new(
          address1: '455 N. Rexford Dr.',
          address2: '3rd Floor',
          city: 'Beverly Hills',
          country: 'US',
          fax: '1-310-275-8159',
          phone: '1-310-285-1013',
          state: 'CA',
          zip: '90210'
        )
      end

      # Whether retrieving an existing rate is implemented.
      # @return [Boolean]
      def find_estimate_implemented?
        false
      end

      # Whether finding rates is implemented.
      # @return [Boolean]
      def find_rates_implemented?
        false
      end

      # Whether finding rates with declared value (thus insurance) is implemented.
      # @return [Boolean]
      def find_rates_with_declared_value?
        false
      end

      # Whether retrieving tracking information is implemented.
      # @return [Boolean]
      def find_tracking_info_implemented?
        false
      end

      # Whether retrieving tracking number from pickup number is implemented.
      # @return [Boolean]
      def find_tracking_number_from_pickup_number_implemented?
        false
      end

      # The address field maximum length accepted by the carrier
      # @return [Integer]
      def maximum_address_field_length
        255
      end

      # The maximum height the carrier will accept.
      # @return [Measured::Length]
      def maximum_height
        Measured::Length.new(105, :inches)
      end

      # The maximum weight the carrier will accept.
      # @return [Measured::Weight]
      def maximum_weight
        Measured::Weight.new(10_000, :pounds)
      end

      # What length overlength fees the carrier begins charging at.
      # @return [Measured::Length]
      def minimum_length_for_overlength_fees
        Measured::Length.new(48, :inches)
      end

      # Whether or not the carrier quotes overlength fees via API.
      # @note Should the API not calculate these fees, they should be calculated some other way outside of Interstellar.
      # @return [Boolean]
      def overlength_fees_require_tariff?
        true
      end

      # Whether carrier considers pickup number the same as the tracking number.
      def pickup_number_is_tracking_number?
        false
      end

      # Whether proof of delivery (POD) retrieval is implemented.
      # @return [Boolean]
      def pod_implemented?
        false
      end

      # Returns the keywords passed to `#initialize` that cannot be blank.
      # @return [Array<Symbol>]
      def requirements
        []
      end

      # Returns the `Credential` methods (passed to `#initialize`) that cannot respond with blank values.
      # @return [Array<Symbol>]
      def required_credential_types
        %i[api]
      end

      # Whether scanned bill of lading (BOL) retrieval is implemented.
      # @return [Boolean]
      def scanned_bol_implemented?
        false
      end
    end

    attr_accessor :conf, :rates_with_excessive_length_fees, :tmpdir
    attr_reader :credentials, :customer_location, :last_request, :tariff

    # @param credentials [Array<Credential>]
    # @param customer_location [Location]
    # @param tariff [Tariff]
    def initialize(credentials, customer_location: nil, tariff: nil)
      credentials = [credentials] if credentials.is_a?(Credential)

      unless credentials.map(&:class).uniq == [Credential]
        raise ArgumentError,
              "#{self.class.name}#new: `credentials` must be a Credential or Array of Credential"
      end

      missing_credential_types = self.class.required_credential_types.uniq - credentials.map(&:type).uniq

      unless missing_credential_types.empty?
        raise ArgumentError,
              "#{self.class.name}#new: `Credential` of type(s) missing: #{missing_credential_types.join(', ')}"
      end

      @credentials = credentials

      if customer_location
        unless customer_location.is_a?(Location)
          raise ArgumentError,
                "#{self.class.name}#new: `customer_location` must be a Location"
        end

        @customer_location = customer_location
      end

      if tariff
        raise ArgumentError, "#{self.class.name}#new: `tariff` must be a Tariff" unless tariff.is_a?(Tariff)

        @tariff = tariff
      end

      conf_path = File
                  .join(
                    File.expand_path(
                      '../../../../configuration/carriers',
                      self.class.const_source_location(:REACTIVE_FREIGHT_CARRIER).first
                    ),
                    "#{self.class.to_s.split('::')[1].underscore}.yml"
                  )
      @conf = YAML.safe_load(File.read(conf_path), permitted_classes: [Symbol])

      @rates_with_excessive_length_fees = @conf.dig(:attributes, :rates, :with_excessive_length_fees)
    end

    # Asks the carrier for the scanned proof of delivery that the carrier would provide after delivery.
    #
    # @param [String] tracking_number Tracking number.
    # @return [DocumentResponse]
    def pod(tracking_number)
      raise NotImplementedError, "#{self.class.name}: #pod not supported"
    end

    # Asks the carrier for the bill of lading that the carrier would provide before shipping.
    #
    # @see #scanned_bol
    #
    # @param [String] tracking_number Tracking number.
    # @return [DocumentResponse]
    def bol(tracking_number)
      raise NotImplementedError, "#{self.class.name}: #bol not supported"
    end

    # Asks the carrier for the scanned bill of lading that the carrier would provide after shipping.
    #
    # @see #bol
    #
    # @param [String] tracking_number Tracking number.
    # @return [DocumentResponse]
    def scanned_bol(tracking_number)
      raise NotImplementedError, "#{self.class.name}: #scanned_bol not supported"
    end

    def find_estimate(*)
      raise NotImplementedError, "#{self.class.name}: #find_estimate not supported"
    end

    # Asks the carrier for a list of locations (terminals) for a given country
    #
    # @param [ActiveUtils::Country] country
    # @return [Array<Location>]
    def find_locations(country)
      raise NotImplementedError, "#{self.class.name}: #find_locations not supported"
    end

    def find_tracking_number_from_pickup_number(pickup_number, date)
      raise NotImplementedError, "#{self.class.name}: #find_tracking_number_from_pickup_number not supported"
    end

    # Asks the carrier for rate estimates for a given shipment.
    #
    # @note Override with whatever you need to get the rates from the carrier.
    #
    # @param shipment [Interstellar::Shipment] Shipment details.
    # @return [Interstellar::RateResponse] The response from the carrier, which
    #   includes 0 or more rate estimates for different shipping products
    def find_rates(shipment:)
      raise NotImplementedError, "#find_rates is not supported by #{self.class.name}."
    end

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
    # @param dispatcher [Interstellar::Contact] The dispatcher.
    # @param pickup_from [ActiveSupport::TimeWithZone] Local date, time and time zone that
    #   pickup hours begin.
    # @param pickup_to [ActiveSupport::TimeWithZone] Local date, time and time zone that
    #   pickup hours end.
    # @param scac [String] The carrier SCAC code (can be `nil`; only used for brokers).
    # @param service [Symbol] The service type.
    # @param shipment [Interstellar::Shipment] The shipment including `#destination.contact`, `#origin.contact`.
    # @return [Interstellar::ShipmentResponse] The response from the carrier. This
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
      raise NotImplementedError, "#create_pickup is not supported by #{self.class.name}."
    end

    # Cancels a shipment with a carrier.
    #
    # @note Override with whatever you need to cancel a shipping label
    #
    # @param tracking_number [String] The tracking number of the shipment to cancel.
    # @return [Interstellar::Response] The response from the carrier. This
    #   response in most cases has a cancellation id.
    def cancel_shipment(tracking_number)
      raise NotImplementedError, "#cancel_shipment is not supported by #{self.class.name}."
    end

    # Retrieves tracking information for a previous shipment
    #
    # @note Override with whatever you need to get a shipping label
    #
    # @param tracking_number [String] The tracking number of the shipment to track.
    # @return [Interstellar::TrackingResponse] The response from the carrier. This
    #   response should a list of shipment tracking events if successful.
    def find_tracking_info(tracking_number)
      raise NotImplementedError, "#find_tracking_info is not supported by #{self.class.name}."
    end

    # Get a list of services available for the a specific route.
    #
    # @param origin [Location] The origin location.
    # @param destination [Location] The destination location.
    # @return [Array<Symbol>] A list of service type symbols for the available services.
    #
    def available_services(origin, destination)
      raise NotImplementedError, "#available_services is not supported by #{self.class.name}."
    end

    # Fetch credential of given type.
    #
    # @param type [Symbol] Type of credential to find, should be one of: `:api`, `:selenoid`, `:website`.
    # @return [Interstellar::Credential|NilClass]
    def fetch_credential(type)
      @fetch_credentials ||= {}
      return @fetch_credentials[type] unless @fetch_credentials[type].blank?

      @fetch_credentials[type] ||= credentials.find { |credential| credential.type == type }
    end

    # Validate credentials with a call to the API.
    #
    # By default this just does a `find_rates` call with the origin and destination both as
    # the carrier's default_location. Override to provide alternate functionality.
    #
    # @return [Boolean] Should return `true` if the provided credentials proved to work,
    #   `false` otherswise.
    def valid_credentials?
      location = self.class.default_location
      find_rates(location, location, Package.new(100, [5, 15, 30]))
    rescue Interstellar::ResponseError
      false
    else
      true
    end

    # Validate the tracking number (may call API).
    #
    # @param [String] tracking_number Tracking number.
    # @return [Boolean] Should return `true` if the provided pro is valid.
    def valid_tracking_number?(tracking_number)
      raise NotImplementedError, "#valid_pro is not supported by #{self.class.name}."
    end

    def overlength_fee(tarrif, package)
      max_dimension_inches = [package.length(:inches), package.width(:inches)].max

      return 0 if max_dimension_inches < self.class.minimum_length_for_overlength_fees.convert_to(:inches).value

      tarrif.overlength_rules.each do |overlength_rule|
        next if max_dimension_inches < overlength_rule[:min_length].convert_to(:inches).value

        if overlength_rule[:max_length].blank? || max_dimension_inches <= overlength_rule[:max_length].convert_to(:inches).value
          return (package.quantity * overlength_rule[:fee_cents])
        end
      end

      0
    end

    # Determine whether the carrier will accept the packages based on credentials and/or tariff.
    # @param packages [Array<Interstellar::Package>]
    # @param tariff [Interstellar::Tariff]
    # @return [Boolean]
    def validate_packages(packages, tariff = nil)
      return false if packages.blank?

      message = []

      max_height_inches = self.class.maximum_height.convert_to(:inches).value
      unless packages.map { |p| p.height(:inches) }.max <= max_height_inches
        message << "items must be #{max_height_inches.to_f} inches tall or less"
      end

      max_weight_pounds = self.class.maximum_weight.convert_to(:pounds).value
      unless packages.sum { |p| p.pounds(:total) } <= max_weight_pounds
        message << "items must weigh #{max_weight_pounds.to_f} lbs or less"
      end

      if self.class.overlength_fees_require_tariff? && (tariff.blank? || !tariff.is_a?(Interstellar::Tariff))
        missing_dimensions = packages.map do |p|
          [p.height(:inches), p.length(:inches), p.width(:inches)].any?(&:zero?)
        end.any?(true)

        if missing_dimensions
          message << 'item dimensions are required'
        else
          max_length_inches = self.class.minimum_length_for_overlength_fees.convert_to(:inches).value

          unless packages.map { |p| [p.width(:inches), p.length(:inches)].max }.max < max_length_inches
            message << 'tariff must be defined to calculate overlength fees'
          end
        end
      end

      raise UnserviceableError, message.join(', ').capitalize unless message.blank?

      true
    end

    def serviceable_accessorials?(accessorials)
      return true if accessorials.blank?

      unless self.class::REACTIVE_FREIGHT_CARRIER
        raise NotImplementedError, "#{self.class.name}: #serviceable_accessorials? not supported"
      end

      return false if @conf.dig(:accessorials, :mappable).blank?

      conf_mappable_accessorials = @conf.dig(:accessorials, :mappable)
      conf_unquotable_accessorials = @conf.dig(:accessorials, :unquotable)
      conf_unserviceable_accessorials = @conf.dig(:accessorials, :unserviceable)

      unserviceable_accessorials = []

      accessorials.each do |accessorial|
        if !conf_unserviceable_accessorials.blank? && conf_unserviceable_accessorials.any?(accessorial)
          unserviceable_accessorials << accessorial
          next
        end

        next if !conf_mappable_accessorials.blank? && conf_mappable_accessorials.keys.any?(accessorial)
        next if !conf_unquotable_accessorials.blank? && conf_unquotable_accessorials.any?(accessorial)

        unserviceable_accessorials << accessorial
      end

      unless unserviceable_accessorials.blank?
        raise Interstellar::UnserviceableAccessorialsError.new(accessorials: unserviceable_accessorials)
      end

      true
    end

    protected

    include ActiveUtils::RequiresParameters
    include ActiveUtils::PostsData

    # Use after building the request to save for later inspection.
    # @return [void]
    def save_request(r)
      @last_request = r
    end

    # Calculates a timestamp that corresponds a given number of business days in the future
    #
    # @param days [Integer] The number of business days from now.
    # @return [DateTime] A timestamp, the provided number of business days in the future.
    def timestamp_from_business_day(days)
      return unless days

      date = DateTime.now.utc

      days.times do
        date += 1.day

        date += 2.days if date.saturday?
        date += 1.day if date.sunday?
      end

      date.to_datetime
    end
  end
end
