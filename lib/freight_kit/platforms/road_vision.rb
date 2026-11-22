module FreightKit
  module Platforms
    # Carriers that run RoadVision, which serves the same JSON API for each of them. Subclasses on another domain override
    # `API[:domain]`. Requests send the carrier's logon code and password: in the query of GETs, and in the body of POSTs.
    #
    # Keys are camelized in {#commit} and underscored in {#parse}, so everything else uses snake_case symbols.
    class RoadVision < Platform
      class << self
        def required_credential_types = %i[api]

        def requirements
          return %i[credentials tariff] if overlength_fees_require_tariff?

          %i[credentials]
        end

        def services = %i[standard]
      end

      include FreightKit::Pickupable
      include FreightKit::Rateable
      include FreightKit::Trackable

      API = {
        domain: 'relmapi.roadvision.com',
        endpoints: {
          bol: '/api/FetchBOL',
          invoice: '/api/FetchInvoiceData',
          invoice_pdf: '/api/FetchInvPDF',
          invoices: '/api/FetchInvoiceListByPro',
          pickup: '/api/SubmitPickupRequest',
          pod: '/api/FetchPOD',
          rates: '/api/FetchQuoteRequest',
          track: '/api/GetShipmentStatus',
          transit_time: '/api/TransitTime'
        },
        methods: { pickup: :post, rates: :post },
        # Seconds. Invoices that bill many shipments take longer than {HTTPClient::TIMEOUTS} allows.
        read_timeouts: { invoice: 120, invoice_pdf: 120 }
      }.freeze
      # Request keys that `String#camelize` misses
      CAMELIZED_KEYS = { bol: 'BOL', cod_amount_in_cents: 'CODAmountInCents', ponum: 'PONUM', ppd_or_col: 'PPDorCOL', sid: 'SID' }.freeze
      # {ShipmentEvent#type_code} => EDI X12 214 status code
      EVENTS = { arrived_at_terminal: 'X4', delivered: 'D1', departed: 'P1', out_for_delivery: 'X6', picked_up: 'AF' }.freeze
      JSON_HEADERS = { Accept: 'application/json', 'Content-Type': 'application/json' }.freeze
      # The `ErrorInfo` of `FetchInvoiceListByPro` for shipments that are not invoiced yet
      NO_INVOICES_MESSAGE = /no corresponding invoices/i
      # The `SearchType` that looks shipments up by PRO
      PRO_SEARCH_TYPE = 1
      # Response keys that `String#underscore` misses
      UNDERSCORED_KEYS = {
        'BOLnumber' => :bol_number,
        'POnumber' => :po_number,
        'SIDnumber' => :sid_number,
        **CAMELIZED_KEYS.invert
      }.freeze

      # Fetches the shipment's latest invoice, with its PDF.
      #
      # @param tracking_number [String] The PRO.
      # @return [InvoiceResponse] With a {DocumentNotFoundError} when the shipment is not invoiced yet, or the invoice has
      #   no PDF. The amounts and lines are set in the second case.
      def invoice(tracking_number)
        list = parse(commit(:invoices, { pro_number: tracking_number }))
        error = parse_error(list)
        error = DocumentNotFoundError.new(error.message) if error&.message&.match?(NO_INVOICES_MESSAGE)
        invoice_response = InvoiceResponse.new(error:, request: last_request, response: list)
        return invoice_response if invoice_response.error

        number = list[:invoice_pick_list].to_a.filter_map { |item| text(item[:invoice_number]) }.max_by(&:to_i)
        return invoice_response.tap { |response| response.error = DocumentNotFoundError.new } if number.nil?

        data = parse(commit(:invoice, { invoice_number: number }))
        invoice_response = InvoiceResponse.new(error: parse_error(data), request: last_request, response: data)
        return invoice_response if invoice_response.error

        pdf = document(:invoice_pdf, { doc_number: number })

        invoice_response.tap do |response|
          response.assign_attributes(
            balance_cents: cents(data[:invoice_balance]),
            content_type: pdf.content_type,
            currency: 'USD',
            data: pdf.data,
            error: pdf.error,
            issued_on: date(data[:invoice_date]),
            lines: data[:invoice_details].to_a.map { |detail| invoice_line(detail) },
            number: text(data[:invoice_number]) || number,
            total_cents: cents(data[:invoice_amount])
          )
        end
      end

      # @param tracking_number [String] The PRO.
      # @return [DocumentResponse] With a {DocumentNotFoundError} when the shipment has none yet.
      def pod(tracking_number) = document(:pod, build_tracking_request(tracking_number))

      # @param tracking_number [String] The PRO.
      # @return [DocumentResponse] With a {DocumentNotFoundError} when the shipment has none yet.
      def scanned_bol(tracking_number) = document(:bol, build_tracking_request(tracking_number))

      protected

      # Raises {UnserviceableAccessorialsError} rather than quote without accessorials that the carrier does not map
      def build_accessorials(shipment)
        accessorials = shipment.accessorials.to_a
        return [] if accessorials.empty?
        raise UnserviceableAccessorialsError.new(accessorials:) unless serviceable_accessorials?(accessorials)

        codes = accessorials.flat_map { |accessorial| Array(mappable_accessorials[accessorial]) }
        codes.uniq.map { |code| { accessorial_code: code } }
      end

      def build_freight_list(shipment)
        shipment.packages.map do |package|
          {
            freight_class: package.freight_class.to_s,
            freight_description: package.description,
            height: package.height(:in).ceil,
            length: package.length(:in).ceil,
            pallet_count: package.packaging.pallet? ? package.quantity : 0,
            piece_count: package.quantity,
            weight: package.pounds(:total).ceil,
            width: package.width(:in).ceil
          }.compact
        end
      end

      # The API keeps only the local wall-clock time of the pickup hours. The quote number books the quoted price.
      def build_pickup_request(pickup_from:, pickup_to:, shipment:, **)
        {
          accessorial_list: build_accessorials(shipment),
          closing_time: pickup_to&.strftime('%H:%M'),
          cod_amount_in_cents: 0,
          freight_list: build_freight_list(shipment),
          pickup_date: pickup_from.strftime('%m/%d/%Y'),
          ponum: shipment.po_number,
          ppd_or_col: 'PPD',
          quote_num: shipment.estimate_reference.presence&.to_i,
          ready_by_time: pickup_from.strftime('%H:%M'),
          sid: shipment.order_number
        }.merge(stop(:consignee, shipment.destination), stop(:shipper, shipment.origin)).compact
      end

      def build_rate_request(shipment:)
        destination = shipment.destination
        origin = shipment.origin

        {
          accessorial_list: build_accessorials(shipment),
          cod_amount_in_cents: 0,
          freight_list: build_freight_list(shipment),
          inbound: 'N',
          ppd_or_col: 'PPD',
          ship_from_city: origin.city,
          ship_from_state: origin.province,
          ship_from_zip: zip(origin),
          ship_to_city: destination.city,
          ship_to_state: destination.province,
          ship_to_zip: zip(destination)
        }
      end

      def build_tracking_request(tracking_number) = { search_for: tracking_number, search_type: PRO_SEARCH_TYPE }

      def camelize_keys(hash) = hash.deep_transform_keys { |key| CAMELIZED_KEYS[key] || key.to_s.camelize }

      # Amounts are strings or numbers in dollars
      def cents(amount) = (amount.to_s.delete('^0-9.-').to_d * 100).round.to_i

      def commit(action, params)
        api = self.class::API
        credential = fetch_credential(:api)
        url = "https://#{api[:domain]}#{api.dig(:endpoints, action)}"

        request = if api.dig(:methods, action) == :post
                    body = camelize_keys({ logon: credential.username, pass: credential.password }.merge(params)).to_json
                    { body:, headers: JSON_HEADERS, method: :post, url: }
                  else
                    query = camelize_keys({ pass: credential.password, user: credential.username }.merge(params))
                    { headers: JSON_HEADERS.slice(:Accept), method: :get, query:, url: }
                  end

        save_request(request)
        read_timeout = api.dig(:read_timeouts, action)
        response = HTTPClient.request(request[:method], url, **request.slice(:body, :headers, :query), proxy_url:, read_timeout:)
        raise HTTPError.new(body: response.body, code: response.code) unless response.code == 200

        response
      end

      # Dates are `MM/DD/YYYY`
      def date(value)
        value = text(value)
        return if value.nil?

        value.match?(/\A\d{4}-/) ? ::Date.iso8601(value.first(10)) : ::Date.strptime(value.split.first.tr('-', '/'), '%m/%d/%Y')
      rescue ::Date::Error
        nil
      end

      # Times are `HH:MM`, on a 24-hour clock, and `00:00` when the status has none
      def date_time(status, location)
        local_date = date(status[:status_date])
        return if local_date.nil?

        time = text(status[:status_time])
        return DateTime.new(local_date:, location:) unless time&.match?(/\A\d{1,2}:\d{2}\z/) && time.delete(':').to_i.positive?

        DateTime.new(local_date_time: "#{local_date.iso8601} #{time.rjust(5, '0')}:00", location:)
      end

      # The API returns documents as PDFs, and anything else when they are missing
      def document(action, params)
        response = commit(action, params)
        document_response = DocumentResponse.new(request: last_request)
        return document_response.tap { |item| item.error = DocumentNotFoundError.new } unless response.body.start_with?('%PDF')

        document_response.tap { |item| item.assign_attributes(content_type: 'application/pdf', data: response.body) }
      end

      def invoice_line(detail)
        InvoiceLine.new(
          balance_cents: cents(detail[:balance_due]),
          bol_number: text(detail[:bol]),
          delivered_on: date(detail[:delivery_date]),
          destination: location(detail.transform_keys { |key| key.to_s.delete_prefix('consignee_').to_sym }),
          order_number: text(detail[:sid]),
          origin: location(detail.transform_keys { |key| key.to_s.delete_prefix('shipper_').to_sym }),
          picked_up_on: date(detail[:pickup_date]),
          po_number: text(detail[:po_number]),
          total_cents: cents(detail[:original_charges]),
          tracking_number: text(detail[:pro_number])
        )
      end

      # Canadian postal codes have letters
      def location(fields)
        return if fields.blank? || fields.values_at(:city, :state, :zip).none? { |value| text(value) }

        name = text(fields[:name])
        postal_code = text(fields[:zip])

        Location.new(
          address1: text(fields[:address1]),
          address2: text(fields[:address2]),
          address3: text(fields[:address3]),
          city: text(fields[:city])&.titleize,
          contact: (Contact.new(company_name: name) if name),
          country: ActiveUtils::Country.find(postal_code.to_s.match?(/[a-z]/i) ? 'CA' : 'US'),
          postal_code:,
          province: text(fields[:state])&.upcase
        )
      end

      # @return [Hash, Object] The parsed JSON response, with snake_case symbol keys.
      def parse(response)
        data = response.parsed_response
        data.is_a?(Hash) ? data.deep_transform_keys { |key| UNDERSCORED_KEYS[key] || key.to_s.underscore.to_sym } : data
      end

      # Every response has an error message field, which is blank on success
      def parse_error(data, key: :error_info)
        return ResponseError.new("Unexpected response: #{data.to_s.truncate(200)}") unless data.is_a?(Hash)

        text(data[key])&.then { |message| ResponseError.new(message) }
      end

      def parse_pickup_response(response)
        data = parse(response)
        pickup_response = PickupResponse.new(error: parse_error(data), request: last_request, response: data)
        return pickup_response if pickup_response.error

        pickup_number = data[:pickup_number].to_i
        return pickup_response.tap { |item| item.error = ResponseError.new('Pickup number is blank') } unless pickup_number.positive?

        pickup_response.tap { |item| item.pickup_number = pickup_number.to_s }
      end

      # Prices are the quote's line items, plus whatever they leave of its total
      def parse_rate_response(shipment:, response:)
        data = parse(response)
        rate_response = RateResponse.new(error: parse_error(data), request: last_request, response: data)
        return rate_response if rate_response.error

        total_cents = cents(data[:total])
        return rate_response.tap { |item| item.error = ResponseError.new('Total is blank') } unless total_cents.positive?

        prices = data[:quote_details].to_a.map do |line|
          Price.new(blame: :api, cents: cents(line[:amount]), description: text(line[:description]))
        end

        remainder_cents = total_cents - prices.sum(&:cents)
        prices << Price.new(blame: :api, cents: remainder_cents, description: prices.empty? ? 'Total' : 'Other') if remainder_cents.nonzero?

        if self.class.overlength_fees_require_tariff?
          overlength_cents = shipment.packages.sum { |package| overlength_fee(tariff, package) }
          prices << Price.new(blame: :tariff, cents: overlength_cents, description: 'Overlength fees') if overlength_cents.nonzero?
        end

        rate = Rate.new(
          carrier: self,
          carrier_name: name,
          currency: 'USD',
          estimate_reference: data[:quote_number].presence&.to_s,
          prices:,
          scac:,
          service_name: :standard,
          shipment:,
          transit_days: transit_days(shipment),
          with_excessive_length_fees: rates_with_excessive_length_fees?
        )

        rate_response.tap { |item| item.rates = [rate] }
      end

      def parse_tracking_response(tracking_number, response:)
        data = parse(response)
        tracking_response = TrackingResponse.new(carrier: self, carrier_name: name, request: last_request, response: data, tracking_number:)
        tracking_response.error = parse_error(data, key: :error_message)
        return tracking_response if tracking_response.error

        info = data[:general_info].to_h
        return tracking_response.tap { |item| item.error = ShipmentNotFoundError.new } if text(info[:pro_number]).nil?

        destination = location(data[:ship_to])
        origin = location(data[:ship_from])
        statuses = data[:status_list].to_a
        shipment_events = statuses.filter_map { |status| shipment_event(status, destination:, origin:) }

        tracking_response.assign_attributes(
          actual_delivery_date: shipment_events.find { |event| event.type_code == :delivered }&.date_time,
          delivery_signature: text(info[:who_signed]),
          destination:,
          origin:,
          ship_time: date(info[:shipment_date])&.then { |local_date| DateTime.new(local_date:, location: origin) },
          shipment_events:,
          shipper_address: origin,
          status: shipment_events.last&.type_code,
          status_code: text(statuses.last.to_h[:status_code]),
          status_description: text(statuses.last.to_h[:status_definition]),
          tracking_number: text(info[:pro_number])
        )

        tracking_response
      end

      # Statuses have no location, so events take the origin or destination when they happen there
      def shipment_event(status, destination:, origin:)
        type_code = self.class::EVENTS.key(text(status[:status_code])&.upcase)
        return if type_code.nil?

        location = type_code == :picked_up ? origin : (destination if %i[delivered out_for_delivery].include?(type_code))

        ShipmentEvent.new(date_time: date_time(status, location), location:, type_code:)
      end

      # A pickup request's fields for the shipper or consignee, which the API limits to 30 characters
      def stop(role, location)
        contact = location.contact
        fields = {
          address: location.address1,
          city: location.city,
          contact: contact&.name,
          name: contact&.company_name || contact&.name,
          phone: contact&.phone,
          state: location.province,
          zip: zip(location)
        }

        fields.to_h { |key, value| [:"#{role}_#{key}", value&.to_s&.first(30)] }
      end

      def text(value) = value.to_s.squish.presence

      # A transit time lookup that fails leaves the rate without transit days, rather than without the rate
      def transit_days(shipment)
        data = parse(commit(:transit_time, { destination_zip: zip(shipment.destination), origin_zip: zip(shipment.origin) }))

        text(data[:transit_days])&.to_i if parse_error(data).nil?
      rescue Error, HTTPX::Error, SystemCallError
        nil
      end

      # 5-digit US ZIP codes, and Canadian postal codes without spaces
      def zip(location) = location.postal_code.to_s.delete(' ').split('-').first
    end
  end
end
