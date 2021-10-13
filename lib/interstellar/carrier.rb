module Interstellar
  # Carrier is the abstract base class for all supported carriers.
  #
  # To implement support for a carrier, you should subclass this class and
  # implement all the methods that the carrier supports.
  #
  # @see #find_rates
  # @see #create_pickup
  # @see #cancel_shipment
  # @see #find_tracking_info
  #
  # @!attribute test_mode
  #   Whether to interact with the carrier's sandbox environment.
  #   @return [Boolean]
  #
  # @!attribute last_request
  #   The last request performed against the carrier's API.
  #   @see #save_request
  class Carrier
    attr_accessor :conf, :rates_with_excessive_length_fees, :test_mode, :tmpdir
    attr_reader :last_request

    alias test_mode? test_mode

    # Credentials should be in options hash under keys :login, :password and/or :key.
    # @param options [Hash] The details needed to connect to the carrier's API.
    # @option options [Boolean] :test Set this to true to connect to the carrier's
    #   sandbox environment instead of the production environment.
    def initialize(options = {})
      requirements.each { |key| requires!(options, key) }
      @conf = nil
      @debug = options[:debug].blank? ? false : true
      @last_request = nil
      @test_mode = options[:test]
      @tmpdir = options[:tmpdir] || Dir.tmpdir

      return unless self.class::REACTIVE_FREIGHT_CARRIER

      # Sanitize options[:watir_args]
      unless options[:watir_args].blank?
        options[:watir_args] = [:chrome, { options: { prefs: {} } }] unless options[:watir_args]
        options[:watir_args].each do |h|
          if h.is_a?(Hash)
            h.merge!(options: { prefs: {} }) unless h.dig(:options, :prefs)
            if !options[:selenoid_options]
              h[:options][:prefs].merge!(
                download: {
                  prompt_for_download: false,
                  default_directory: @tmpdir
                }
              )
            else
              h[:options][:prefs].merge!(
                download: {
                  directory_upgrade: true,
                  prompt_for_download: false
                }
              )
            end
          end
          h
        end
      end

      @options = options

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

    def find_bol(*)
      raise NotImplementedError, "#{self.class.name}: #find_bol not supported"
    end

    def find_bol_implemented?
      false
    end

    def find_estimate(*)
      raise NotImplementedError, "#{self.class.name}: #find_estimate not supported"
    end

    def find_estimate_implemented?
      false
    end

    def find_pod(*)
      raise NotImplementedError, "#{self.class.name}: #find_pod not supported"
    end

    def find_pod_implemented?
      false
    end

    # Asks the carrier for rate estimates for a given shipment.
    #
    # @note Override with whatever you need to get the rates from the carrier.
    #
    # @param origin [Interstellar::Location] Where the shipment will originate from.
    # @param destination [Interstellar::Location] Where the package will go.
    # @param packages [Array<Interstellar::Package>] The list of packages that will
    #   be in the shipment.
    # @param options [Hash] Carrier-specific parameters.
    # @return [Interstellar::RateResponse] The response from the carrier, which
    #   includes 0 or more rate estimates for different shipping products
    def find_rates(_origin, _destination, _packages, _options = {})
      raise NotImplementedError, "#find_rates is not supported by #{self.class.name}."
    end

    def find_rates_implemented?
      false
    end

    # Registers a new pickup with the carrier, to get a tracking number and
    # potentially shipping labels
    #
    # @note Override with whatever you need to register a shipment, and obtain
    #   shipping labels if supported by the carrier.
    #
    # @param origin [Interstellar::Location] Where the shipment will originate from.
    # @param destination [Interstellar::Location] Where the package will go.
    # @param packages [Array<Interstellar::Package>] The list of packages that will
    #   be in the shipment.
    # @param options [Hash] Carrier-specific parameters.
    # @return [Interstellar::ShipmentResponse] The response from the carrier. This
    #   response should include a shipment identifier or tracking_number if successful,
    #   and potentially shipping labels.
    def create_pickup(_origin, _destination, _packages, _options = {})
      raise NotImplementedError, "#create_pickup is not supported by #{self.class.name}."
    end

    def create_pickup_implemented?
      false
    end

    # Cancels a shipment with a carrier.
    #
    # @note Override with whatever you need to cancel a shipping label
    #
    # @param shipment_id [String] The unique identifier of the shipment to cancel.
    #  This can be shipment_id or tracking number depending on carrier. Up to you and
    #  the carrier
    # @param options [Hash] Carrier-specific parameters.
    # @return [Interstellar::ShipmentResponse] The response from the carrier. This
    #   response in most cases has a cancellation id.
    def cancel_shipment(_shipment_id, _options = {})
      raise NotImplementedError, "#cancel_shipment is not supported by #{self.class.name}."
    end

    def cancel_shipment_implemented?
      false
    end

    # Retrieves tracking information for a previous shipment
    #
    # @note Override with whatever you need to get a shipping label
    #
    # @param tracking_number [String] The unique identifier of the shipment to track.
    # @param options [Hash] Carrier-specific parameters.
    # @return [Interstellar::TrackingResponse] The response from the carrier. This
    #   response should a list of shipment tracking events if successful.
    def find_tracking_info(_tracking_number, _options = {})
      raise NotImplementedError, "#find_tracking_info is not supported by #{self.class.name}."
    end

    def find_tracking_info_implemented?
      false
    end

    # Get a list of services available for the a specific route
    #
    # @param origin_country_code [String] The country of origin
    # @param destination_country_code [String] The destination country
    # @return [Array<String>] A list of names of the available services
    #
    def available_services(_origin_country_code, _destination_country_code, _options = {})
      raise NotImplementedError, "#available_services is not supported by #{self.class.name}."
    end

    def available_services_implemented?
      false
    end

    # Validate credentials with a call to the API.
    #
    # By default this just does a `find_rates` call with the origin and destination both as
    # the carrier's default_location. Override to provide alternate functionality, such as
    # checking for `test_mode` to use test servers, etc.
    #
    # @return [Boolean] Should return `true` if the provided credentials proved to work,
    #   `false` otherswise.
    def valid_credentials?
      location = self.class.default_location
      find_rates(location, location, Package.new(100, [5, 15, 30]), test: test_mode)
    rescue Interstellar::ResponseError
      false
    else
      true
    end

    # The maximum weight the carrier will accept.
    # @return [Measured::Weight]
    def maximum_weight
      Measured::Weight.new(10_000, :pounds)
    end

    # The address field maximum length accepted by the carrier
    # @return [Integer]
    def maximum_address_field_length
      255
    end

    def serviceable_accessorials?(accessorials)
      return true if accessorials.blank?

      if !self.class::REACTIVE_FREIGHT_CARRIER ||
         !@conf.dig(:accessorials, :mappable) ||
         !@conf.dig(:accessorials, :unquotable) ||
         !@conf.dig(:accessorials, :unserviceable)
        raise NotImplementedError, "#{self.class.name}: #serviceable_accessorials? not supported"
      end

      serviceable_accessorials = @conf.dig(:accessorials, :mappable).keys + @conf.dig(:accessorials, :unquotable)
      serviceable_count = (serviceable_accessorials & accessorials).size

      unserviceable_accessorials = @conf.dig(:accessorials, :unserviceable)
      unserviceable_count = (unserviceable_accessorials & accessorials).size

      if serviceable_count != accessorials.size || !unserviceable_count.zero?
        raise ArgumentError, "#{self.class.name}: Some accessorials unserviceable"
      end

      true
    end

    protected

    include ActiveUtils::RequiresParameters
    include ActiveUtils::PostsData

    # Returns the keys that are required to be passed to the options hash
    # @note Override to return required keys in options hash for initialize method.
    # @return [Array<Symbol>]
    def requirements
      []
    end

    # The default location to use for {#valid_credentials?}.
    # @note Override for non-U.S.-based carriers.
    # @return [Interstellar::Location]
    def self.default_location
      Location.new(country: 'US',
                   state: 'CA',
                   city: 'Beverly Hills',
                   address1: '455 N. Rexford Dr.',
                   address2: '3rd Floor',
                   zip: '90210',
                   phone: '1-310-285-1013',
                   fax: '1-310-275-8159')
    end

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
