module FreightKit
  module Platforms
    # Carriers and brokers that run Next TMS. Every tenant serves the same GraphQL API from its own domain, which each
    # subclass's {ORM} queries, e.g. `FreightKit::Carriers::JFJTransportation::ORM::Shipment.find_by!(id: 1234)`.
    #
    # Subclasses set `API[:domain]`. Requests authenticate with an API key issued in Next TMS (prefixed `tms_`), and act
    # with the permissions of its owner. The API hides fields that the owner cannot see, and the queries select what a
    # customer sees, so they work with a customer's or a broker user's key, but not a broker carrier's.
    class NextTMS < Platform
      class << self
        def inherited(subclass)
          super
          ORM.define(subclass)
        end

        # The TMS prices overlength fees into its rates
        def overlength_fees_require_tariff? = false

        # Both are the load ID
        def pickup_number_is_tracking_number? = true
        def required_credential_types = %i[api_key]

        # The TMS takes FreightKit's accessorial codes, and each customer's broker sets which it prices, so only the quote
        # can tell, with `UNSERVICEABLE_ACCESSORIALS`.
        def serviceable_accessorials?(_accessorials) = true

        def services = %i[standard]
      end

      # How long cached GraphQL results stay in {FreightKit.cache}.
      class_attribute :cache_expires_in, default: 5.minutes

      API = { endpoints: { graphql: '/graphql' }, use_ssl: true }.freeze
      # Shipment milestones, as {ShipmentEvent#type_code} => [{ORM::Shipment} reader, address the event happens at], in the
      # order they happen, which orders milestones with the same time
      EVENTS = {
        pickup_driver_assigned: %i[pickup_driver_assigned_at shipper_address],
        picked_up: %i[picked_up_at shipper_address],
        departed: %i[departed_origin_terminal_at shipper_address],
        pending_delivery_appointment: %i[pending_appointment_since receiver_address],
        out_for_delivery: %i[out_for_delivery_at receiver_address],
        delivered: %i[delivered_at receiver_address],
        lost: [:lost_on, nil]
      }.freeze
      JSON_HEADERS = { Accept: 'application/json', 'Content-Type': 'application/json' }.freeze
      # Seconds between checks for labels, which the TMS generates in background jobs after booking
      LABEL_WAITS = [0.5, 1, 2, 4].freeze

      # Quotes wait on every carrier's rating API, so they take minutes rather than HTTPX's default of 60 seconds
      READ_TIMEOUT = 300

      # Downloads the shipment's bill of lading.
      #
      # @param tracking_number [String] The load ID, or the carrier's PRO.
      # @return [DocumentResponse] With a {DocumentNotFoundError} when the shipment has none yet.
      def bol(tracking_number) = document(tracking_number, :BOL)

      # Quotes the shipment, then books the rate of the carrier with `scac`, or the cheapest rate without one. The TMS
      # keeps only the local wall-clock time of the delivery and pickup hours.
      #
      # @return [PickupResponse] With the load ID as the pickup number, and the labels, which are empty when the TMS did not
      #   generate them within {LABEL_WAITS}. With an {UnserviceableError} when no rate matches, or an
      #   {UnserviceableAccessorialsError} when the customer cannot get an accessorial.
      # @raise [ResponseError] With `UNBOOKABLE_RATE` when the rate expired, or the customer can no longer use the carrier.
      #   The booking uses the quote's addresses, so it never gets `RATE_OUTDATED`.
      def create_pickup(delivery_from:, delivery_to:, pickup_from:, pickup_to:, scac:, shipment:, **)
        pickup_on = pickup_date(shipment, pickup_from)
        rates = quote(shipment, pickup_on)[:rates].select { |rate| rate[:charge_cents] }
        rate = scac.present? ? rates.find { |option| option[:scac] == scac } : rates.min_by { |option| option[:charge_cents] }
        error = UnserviceableError.new("No rate from #{scac.presence || name}")
        return PickupResponse.new(error:, request: last_request) if rate.nil?

        input = {
          customer_reference: shipment.po_number,
          delivery_hours_end_at: delivery_to&.iso8601,
          delivery_hours_start_at: delivery_from&.iso8601,
          pickup_hours_end_at: pickup_to&.iso8601,
          pickup_hours_start_at: pickup_from&.iso8601,
          pickup_on:,
          rate_id: rate[:id],
          receiver: location_input(shipment.destination),
          shipper: location_input(shipment.origin),
          shipper_reference: shipment.order_number
        }
        data = mutate(:shipment_create, **input).dig(:shipment_create, :shipment)
        pickup_response = PickupResponse.new(pickup_number: data[:load_id].to_s, request: last_request, response: data)

        pickup_response.tap { |response| response.labels = fetch_labels(data) }
      rescue UnserviceableAccessorialsError => e
        PickupResponse.new(error: e, request: last_request)
      end

      # Sends a document for {GraphQLClient::HTTPAdapter}. Keys are camelized here and underscored in {#query}, so
      # everything else uses snake_case symbols.
      #
      # @return [Hash] The parsed JSON response.
      def execute(document, operation_name: nil, variables: {})
        api = self.class::API
        variables = variables.deep_symbolize_keys
        request = {
          body: { operationName: operation_name, query: document, variables: camelize_keys(variables) }.to_json,
          headers: JSON_HEADERS.merge(authorization_headers),
          method: :post,
          url: "#{base_url}#{api.dig(:endpoints, :graphql)}",
          variables:
        }

        save_request(request)
        body = commit(request)
        raise ResponseError, "Unexpected response: #{body.to_s.truncate(200)}" unless body.is_a?(Hash)

        body
      end

      # Quotes the shipment with every carrier that the TMS offers the API key's customer.
      #
      # @return [RateResponse] With the quote's load ID as each rate's `estimate_reference`, and an {UnserviceableError}
      #   when no carrier quoted, or an {UnserviceableAccessorialsError} when the customer cannot get an accessorial.
      def find_rates(shipment:)
        data = quote(shipment, pickup_date(shipment))
        quote_number = data.dig(:shipment, :load_id).to_s
        rates = data[:rates].filter_map { |rate| build_rate(rate, quote_number, shipment) if rate[:charge_cents] }

        RateResponse.new(error: (UnserviceableError.new if rates.empty?), rates:, request: last_request, response: data)
      rescue UnserviceableAccessorialsError => e
        RateResponse.new(error: e, request: last_request)
      end

      # Builds events from the carrier's scans, or from the shipment's milestones when the carrier sent none.
      #
      # @param tracking_number [String] The load ID, or the carrier's PRO.
      # @return [TrackingResponse] With a {ShipmentNotFoundError} when no shipment has the number.
      def find_tracking_info(tracking_number)
        tracking_response = TrackingResponse.new(carrier: self, carrier_name: name, tracking_number:)
        shipment = find_shipment(tracking_number)
        tracking_response.assign_attributes(request: last_request, response: shipment&.attributes)
        return tracking_response.tap { |response| response.error = ShipmentNotFoundError.new } if shipment.nil?

        shipment_events = scan_events(shipment).presence || milestone_events(shipment)

        # Appointments without a time have only a date
        delivery_appointment = shipment.delivery_appointment_at || shipment.delivery_appointment_on

        tracking_response.assign_attributes(
          actual_delivery_date: shipment.delivered_at&.then { |value| date_time(value, shipment.receiver_address) },
          destination: shipment.receiver_address&.to_location,
          estimated_delivery_date: shipment.delivery_eta_on&.then { |value| DateTime.new(local_date: value) },
          origin: shipment.shipper_address&.to_location,
          scheduled_delivery_date: delivery_appointment&.then { |value| date_time(value, shipment.receiver_address) },
          ship_time: shipment.picked_up_at,
          shipment_events:,
          shipper_address: shipment.shipper_address&.to_location,
          status: shipment_events.last&.type_code,
          status_code: shipment.status&.to_s,
          status_description: shipment.status&.to_s&.humanize
        )

        tracking_response
      end

      def find_tracking_number_from_pickup_number(pickup_number, _date) = pickup_number

      # Downloads the invoice that the API key's customer received. {ORM::Invoice} lists them.
      #
      # @param tracking_number [String] The load ID, or the carrier's PRO.
      # @return [DocumentResponse] With a {DocumentNotFoundError} when the shipment is not invoiced yet.
      def invoice(tracking_number) = document(tracking_number, :INVOICE)

      # Runs a {GraphQLClient::Mutation} as the API key's user, never from {FreightKit.cache}.
      #
      # @param operation [Symbol] The mutation, e.g. `:quote_create` for {GraphQLClient::Mutation::QuoteCreate}.
      # @param input [Hash] The input, with snake_case keys.
      # @return [Hash] Like {#query}.
      # @raise [ResponseError] Like {#query}, e.g. with `UNBOOKABLE_RATE`.
      def mutate(operation, **input) = commit_query(GraphQLClient::Mutation.const_get(operation.to_s.camelize), { input: input.compact })

      # Downloads the carrier's proof of delivery.
      #
      # @param tracking_number [String] The load ID, or the carrier's PRO.
      # @return [DocumentResponse] With a {DocumentNotFoundError} when the shipment has none yet.
      def pod(tracking_number) = document(tracking_number, :POD)

      # Runs a {GraphQLClient::Query} as the API key's user.
      #
      # @param operation [Symbol] The query, e.g. `:shipment` for {GraphQLClient::Query::Shipment}.
      # @param cache [Boolean] Whether to reuse a result from {FreightKit.cache} for {.cache_expires_in}. Keys include a
      #   digest of the API key, so users with different permissions never share results.
      # @param variables [Hash] Variables, with snake_case keys.
      # @return [Hash] The response's `data`, with snake_case symbol keys.
      # @raise [InvalidCredentialsError] When the tenant rejects the API key, e.g. because it expired.
      # @raise [RateLimitError] When the API key sent too many requests (300 per minute), and {HTTPClient} did not retry
      #   because `retry_after` is too long.
      # @raise [ResponseError] When the response has errors, e.g. `PAGE_OVERFLOW` or `UNAUTHORIZED`.
      def query(operation, cache: false, **variables)
        graphql_class = GraphQLClient::Query.const_get(operation.to_s.camelize)
        variables = variables.compact
        return commit_query(graphql_class, variables) unless cache

        digest = Digest::SHA256.hexdigest([authorization_headers.to_json, operation, variables.to_json].join("\0"))
        FreightKit.cache.fetch("freight_kit/next_tms/#{self.class::API[:domain]}/#{digest}", expires_in: cache_expires_in) do
          commit_query(graphql_class, variables)
        end
      end

      # Downloads the bill of lading that the carrier signed at pickup. Customers cannot see it.
      #
      # @param tracking_number [String] The load ID, or the carrier's PRO.
      # @return [DocumentResponse] With a {DocumentNotFoundError} when the shipment has none, or the API key cannot see it.
      def scanned_bol(tracking_number) = document(tracking_number, :SCANNED_BOL)

      # @param tracking_number [String] The load ID, or the carrier's PRO.
      # @return [Boolean] Whether a shipment that the API key can see has the number.
      def valid_tracking_number?(tracking_number) = shipments_by_tracking_number(tracking_number.to_s).any?

      protected

      # The country comes from the region, e.g. `US_CA`
      def address_input(location)
        region_iso31662 = "#{location.country&.code(:alpha2)}_#{location.province}"
        address = { city: location.city, region_iso31662:, street: location.address1, street2: location.address2 }

        address.merge(zip_code: location.postal_code).compact
      end

      def authorization_headers = { 'X-API-Key': fetch_credential(:api_key).api_key }

      def base_url
        api = self.class::API

        "#{api[:use_ssl] ? 'https' : 'http'}://#{api[:domain]}"
      end

      def build_rate(data, quote_number, shipment)
        Rate.new(
          carrier: self,
          carrier_name: data[:carrier_name],
          currency: data[:charge_currency],
          estimate_reference: quote_number,
          expires_at: data[:expires_at]&.then { |value| Time.iso8601(value) },
          prices: [Price.new(blame: :api, cents: data[:charge_cents], description: 'Total')],
          scac: data[:scac],
          service_name: :standard,
          shipment:,
          transit_days: data[:transit_days],
          with_excessive_length_fees: rates_with_excessive_length_fees?
        )
      end

      def camelize_keys(hash) = hash.deep_transform_keys { |key| key.to_s.camelize(:lower) }

      def commit(request)
        response = HTTPClient.request(request[:method], request[:url], **request.slice(:body, :headers), read_timeout: READ_TIMEOUT)

        raise InvalidCredentialsError, "HTTP #{response.code}: #{response}" if [401, 403].include?(response.code)
        raise RateLimitError.new(body: response.body, code: 429, retry_after: response.headers['retry-after']&.to_i) if response.code == 429
        raise HTTPError.new(body: response.body, code: response.code) unless (200..299).cover?(response.code)

        response.parsed_response
      end

      def commit_query(graphql_class, variables)
        response = GraphQLClient::Client.query(graphql_class::DETAILS, context: { platform: self }, variables:)

        parse_response(response.original_hash)
      end

      def date_time(value, address)
        return DateTime.new(local_date: value) if value.is_a?(Date)

        DateTime.new(date_time_with_zone: value.in_time_zone(address&.time_zone_name || 'UTC'))
      end

      def document(tracking_number, kind)
        data = find_shipment_data(tracking_number, :shipment_documents)
        document_response = DocumentResponse.new(request: last_request, response: data)
        return document_response.tap { |response| response.error = ShipmentNotFoundError.new } if data.nil?

        document = data[:documents].find { |item| item[:kind] == kind.to_s }
        return document_response.tap { |response| response.error = DocumentNotFoundError.new } if document.nil?

        response = download(document[:url])
        document_response.tap { |item| item.assign_attributes(content_type: response.content_type, data: response.body) }
      end

      # URLs are signed and expire after 5 minutes, so they are downloaded right away, without the API key.
      def download(url)
        response = HTTPClient.get(URI.join(base_url, url).to_s)
        raise HTTPError.new(body: response.body, code: response.code) unless response.code == 200

        response
      end

      # A booking stands without labels, so they are empty after the last wait or any failure, rather than an error that
      # a retry would book twice.
      def fetch_labels(shipment_data)
        documents = shipment_data[:documents]

        [*LABEL_WAITS, nil].each do |seconds|
          labels = documents.select { |document| document[:kind] == 'LABEL' }
          return labels.map { |label| Label.new(data: download(label[:url]).body) } if labels.any? || seconds.nil?

          sleep(seconds)
          documents = find_shipment_data(shipment_data[:load_id], :shipment_documents)&.dig(:documents).to_a
        end
      rescue StandardError => e
        HTTPClient.logger.warn("Next TMS load #{shipment_data[:load_id]} booked without labels: #{e.class}: #{e.message}")
        []
      end

      def find_shipment(tracking_number)
        data = find_shipment_data(tracking_number)

        self.class::ORM::Shipment.new(data[:id], loaded: true, **data.except(:id)) if data
      end

      # Customers sometimes track with the carrier's PRO instead of the load ID, which wins when both match. The API
      # scopes shipments to the API key's account. Queries with this instance's credentials, unlike {ORM}, which uses
      # `ORM.credentials`.
      #
      # @raise [ResponseError] When the number is the PRO of several shipments.
      def find_shipment_data(tracking_number, operation = :shipments)
        load_id = load_id(tracking_number)
        items = shipments_by_tracking_number(tracking_number.to_s, operation)
        data = (items.find { |item| item[:load_id] == load_id } if load_id) || (items.first if items.one?)
        raise ResponseError, "#{tracking_number} is the PRO of several shipments, track with the load ID" if data.nil? && items.many?

        data
      end

      # Load IDs are GraphQL Ints, so a longer number can only be a PRO
      def load_id(tracking_number) = Integer(tracking_number.to_s, 10, exception: false)&.then { |id| id if id.between?(1, (2**31) - 1) }

      def local_date(date_time) = date_time.date_time_with_zone&.to_date || date_time.local_date || date_time.local_date_time&.to_date

      def location_input(location)
        contact = location.contact

        {
          address: address_input(location),
          contact_email: contact&.email,
          contact_name: contact&.name,
          contact_phone: contact&.phone,
          name: contact&.company_name
        }.compact
      end

      def milestone_events(shipment)
        milestones = EVENTS.filter_map do |type_code, (reader, address)|
          value = shipment.public_send(reader)
          [type_code, value, address && shipment.public_send(address)] unless value.nil?
        end

        sort_milestones(milestones).map do |type_code, value, address|
          ShipmentEvent.new(date_time: date_time(value, address), location: address&.to_location, type_code:)
        end
      end

      # The weight is of the whole line, and the dimensions of one piece
      def package_input(package)
        type = package.packaging.type

        {
          declared_freight_class: package.declared_freight_class&.to_f,
          description: package.description,
          hazmat: package.hazmat?,
          height: package.height(:inches).ceil.nonzero?,
          length: package.length(:inches).ceil.nonzero?,
          nmfc: package.nmfc,
          packaging: (type == :luggage ? :piece : type).to_s,
          quantity: package.quantity,
          weight: package.pounds(:total).ceil,
          width: package.width(:inches).ceil.nonzero?
        }.compact
      end

      def parse_response(body)
        body = body.deep_transform_keys { |key| key.to_s.underscore.to_sym }
        errors = Array(body[:errors])
        refused = errors.find { |error| error.dig(:extensions, :code) == 'UNSERVICEABLE_ACCESSORIALS' }&.dig(:extensions)
        raise UnserviceableAccessorialsError.new(accessorials: refused[:accessorial_codes].map(&:to_sym)) if refused

        messages = errors.map { |error| [error.dig(:extensions, :code), error[:message]].compact.join(': ') }
        raise ResponseError, messages.join(', ') if messages.any?

        body[:data].to_h
      end

      # Quotes and bookings use the same date, so the booked rate is for the pickup day
      def pickup_date(shipment, pickup_from = nil) = pickup_from&.to_date || shipment.pickup_at&.then { |date_time| local_date(date_time) }

      def quote(shipment, pickup_on)
        packages = shipment.packages

        input = {
          accessorial_codes: Array(shipment.accessorials).map(&:to_s),
          declared_freight_classes: packages.all?(&:declared_freight_class),
          packages: packages.map { |package| package_input(package) },
          pickup_on:,
          receiver_address: address_input(shipment.destination),
          shipper_address: address_input(shipment.origin)
        }

        mutate(:quote_create, **input)[:quote_create]
      end

      # The TMS sorts scans by time, and records their type codes from FreightKit tracking. Scans without a time are skipped.
      def scan_events(shipment)
        shipment.events.filter_map do |event|
          next if event[:occurred_at].nil?

          country = event[:country_alpha2]&.then { |code| ActiveUtils::Country.find(code) }
          province = event[:region_iso31662]&.split(/[-_]/, 2)&.last
          location = Location.new(city: event[:city], country:, postal_code: event[:zip_code], province:)
          date_time = DateTime.new(date_time_with_zone: Time.iso8601(event[:occurred_at]).in_time_zone(location.time_zone || 'UTC'))

          ShipmentEvent.new(date_time:, location:, type_code: event[:type_code].to_sym)
        end
      end

      # The load ID comes first, since other shipments can have it as their PRO. Two PROs are enough to tell a unique PRO
      # from one that several carriers use.
      def shipments_by_tracking_number(tracking_number, operation = :shipments)
        load_id = load_id(tracking_number)
        items = query(operation, filter: { load_id_eq: load_id }, page_size: 1).dig(:shipments, :items) if load_id
        return items if items.present?

        conditions = [{ pro_eq: tracking_number }, { tracking_carrier_pro_eq: tracking_number }]
        query(operation, filter: { or: conditions }, page_size: 2).dig(:shipments, :items)
      end

      # Timed milestones follow their timestamps, then {EVENTS}. Each date-only milestone comes after every milestone of its
      # local day or earlier, e.g. a shipment lost on the day it was picked up.
      def sort_milestones(milestones)
        dated, timed = milestones.partition { |(_, value)| value.is_a?(Date) }
        timed = timed.sort_by.with_index { |(_, value), index| [value.to_time, index] }

        dated.sort_by.with_index { |(_, value), index| [value, index] }.each_with_object(timed) do |milestone, sorted|
          index = sorted.rindex do |(_, value, address)|
            (value.is_a?(Date) ? value : value.in_time_zone(address&.time_zone_name || 'UTC').to_date) <= milestone[1]
          end
          sorted.insert(index ? index + 1 : 0, milestone)
        end
      end
    end
  end
end
