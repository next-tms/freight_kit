# frozen_string_literal: true

module Interstellar
  class FWDA < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Forward Air'
    @@scac = 'FWDA'

    JSON_HEADERS = {
      Accept: 'application/json',
      charset: 'utf-8',
      'Content-Type' => 'application/json'
    }.freeze

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(10_000, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(6, :feet)
    end

    def overlength_fees_require_tariff?
      false
    end

    def required_credential_types
      %i[api]
    end

    # Override Carrier#serviceable_accessorials? since we have separate delivery/pickup accessorials
    def serviceable_accessorials?(accessorials)
      return true if accessorials.blank?

      if !self.class::REACTIVE_FREIGHT_CARRIER ||
         !@conf.dig(:accessorials, :mappable) ||
         !@conf.dig(:accessorials, :unquotable) ||
         !@conf.dig(:accessorials, :unserviceable)
        raise NotImplementedError, "#{self.class.name}: #serviceable_accessorials? not supported"
      end

      serviceable_accessorials = @conf.dig(:accessorials, :mappable, :delivery).keys +
                                 @conf.dig(:accessorials, :mappable, :pickup).keys +
                                 @conf.dig(:accessorials, :unquotable)
      serviceable_count = (serviceable_accessorials & accessorials).size

      unserviceable_accessorials = @conf.dig(:accessorials, :unserviceable)
      unserviceable_count = (unserviceable_accessorials & accessorials).size

      if serviceable_count != accessorials.size || !unserviceable_count.zero?
        raise Interstellar::UnserviceableError, "#{self.class.name}: Some accessorials unserviceable"
      end

      true
    end

    # Documents

    def pod(tracking_number)
      # Retrieve list of available documents first
      documents = commit(build_documents_request(tracking_number))

      begin
        doc_id = get_doc_id(documents:, tracking_number:, type: :pod)
      rescue StandardError => e
        return DocumentResponse.new(e:)
      end

      request = build_document_request(doc_id:, tracking_number:)
      response = commit(request)

      parse_document_response(:pod, tracking_number, response)
    end

    def pod_implemented?
      true
    end

    def scanned_bol(tracking_number, _options = {})
      # Retrieve list of available documents first
      documents = commit(build_documents_request(tracking_number))

      begin
        doc_id = get_doc_id(documents:, tracking_number:, type: :bol)
      rescue StandardError => e
        return DocumentResponse.new(e:)
      end

      request = build_document_request(doc_id:, tracking_number:)
      response = commit(request)

      parse_document_response(:bol, tracking_number, response)
    end

    def scanned_bol_implemented?
      true
    end

    # Pickups

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
      request = build_pickup_request(
        delivery_from:,
        delivery_to:,
        dispatcher:,
        pickup_from:,
        pickup_to:,
        scac:,
        service:,
        shipment:
      )

      parse_pickup_response(commit(request))
    end

    def create_pickup_implemented?
      true
    end

    def pickup_number_is_tracking_number?
      true
    end

    # Locations

    def find_locations(country)
      raise ArgumentError, 'country must be a ActiveUtils::Country' unless country.is_a?(ActiveUtils::Country)

      request = build_locations_request
      parse_locations_response(country:, response: commit(request))
    end

    # Rates

    def find_rates(shipment:)
      begin
        validate_packages(shipment.packages)
      rescue UnserviceableError => e
        return RateResponse.new(error: e)
      end

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit(request))
    end

    def find_rates_implemented?
      true
    end

    def find_rates_with_declared_value?
      true
    end

    # Tracking

    def find_tracking_info(tracking_number, *)
      request = build_tracking_request(tracking_number)

      begin
        response = commit(request)
      rescue StandardError => e
        return TrackingResponse.new(error: e, request:)
      end

      parse_tracking_response(response)
    end

    def find_tracking_info_implemented?
      true
    end

    protected

    def build_accessorials(accessorials)
      delivery_accessorials = []
      pickup_accessorials = []

      unless accessorials.blank?
        serviceable_accessorials?(accessorials)
        accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            if @conf.dig(:accessorials, :mappable, :pickup).include?(a)
              pickup_accessorials << @conf.dig(:accessorials, :mappable, :pickup)[a]
            elsif delivery_accessorials << @conf.dig(:accessorials, :mappable, :delivery)[a]
            end
          end
        end
      end

      if !delivery_accessorials.blank? && delivery_accessorials.include?('RDE')
        # Remove duplicate delivery appointment accessorial when residential delivery (included with RDE)
        delivery_accessorials -= ['ADE']
      end

      if !pickup_accessorials.blank? && pickup_accessorials.include?('RPU')
        # Remove duplicate pickup appointment accessorial when residential pickup (included with RPU)
        pickup_accessorials -= ['APP']
      end

      # API doesn't like empty arrays
      delivery_accessorials = nil if delivery_accessorials.blank?
      pickup_accessorials = nil if pickup_accessorials.blank?

      [pickup_accessorials&.uniq, delivery_accessorials&.uniq]
    end

    def build_dimensions(packages)
      packages.map do |package|
        {
          height: package.height(:in).ceil,
          length: package.length(:in).ceil,
          pieces: package.quantity,
          width: package.width(:in).ceil
        }
      end
    end

    def build_freight_details(packages)
      packages.map do |package|
        {
          description: package.description || 'Freight',
          freightClass: package.freight_class.to_s,
          pieces: package.quantity.to_s,
          weightType: 'L',
          weight: package.pounds(:total).ceil.to_s
        }
      end
    end

    def build_url(action, options = {})
      url = "#{base_url}#{@conf.dig(:api, :endpoints, action)}"
      url = url.gsub('%TRACKING_NUMBER%', options[:tracking_number]) if options[:tracking_number]
      url = url.gsub('%DOC_ID%', options[:doc_id]) if options[:doc_id]

      url
    end

    def base_url
      "https://#{@conf.dig(:api, :domains, :production)}"
    end

    def build_headers
      api_credentials = credentials.find { |c| c.type == :api }

      JSON_HEADERS.merge(
        {
          billToAccountNumber: api_credentials.account,
          customerId: api_credentials.username.upcase,
          password: api_credentials.password,
          user: api_credentials.username
        }
      )
    end

    def build_request(action, options = {})
      headers = JSON_HEADERS
      headers = headers.merge(options[:headers]) unless options[:headers].blank?
      body = options[:body].to_json unless options[:body].blank?

      request = {
        url: build_url(action, options),
        headers:,
        method: @conf.dig(:api, :methods, action),
        body:
      }

      save_request(request)
      request
    end

    def commit(request)
      url = request[:url]
      headers = request[:headers]
      method = request[:method]
      body = request[:body]

      response = case method
                 when :post
                   HTTParty.post(url, headers:, body:, debug_output: $stdout)
                 else
                   HTTParty.get(url, headers:, debug_output: $stdout)
                 end

      raise Interstellar::ResponseError, "HTTP #{response.code}" unless response.code == 200

      return response unless response.headers.content_type == 'application/json'

      json = JSON.parse(response.body)
      error = json.is_a?(Array) ? nil : json['errorMessage']

      return json if error.blank?

      raise Interstellar::InvalidCredentialsError, error if error.downcase.include?('not authorized')
      raise Interstellar::InvalidCredentialsError, error if error.downcase.include?('shipper client does not exist')
      raise Interstellar::ShipmentNotFoundError, error if error.downcase.include?('no history found')
      raise Interstellar::UnserviceableError, error if error.downcase.include?('not serviced')

      raise Interstellar::ResponseError, error
    end

    # Documents

    def get_doc_id(documents:, tracking_number:, type:)
      type = type.to_s.upcase
      link = nil

      documents.each do |document|
        next unless document['documentType'] == type

        link = document['link']
      end

      raise Interstellar::DocumentNotFoundError.new, "API Error: #{@@name}: Document not found" unless link

      query = URI.parse(link).query
      doc_id = CGI.parse(query)['docId']&.first

      raise Interstellar::DocumentNotFoundError.new, "API Error: #{@@name}: Document not found" unless doc_id

      doc_id
    end

    def build_document_request(doc_id:, tracking_number:)
      request = {
        url: build_url(:document, doc_id:, tracking_number:),
        headers: build_headers,
        method: @conf.dig(:api, :methods, :documents)
      }

      save_request(request)
      request
    end

    def build_documents_request(tracking_number)
      request = {
        url: build_url(:documents, tracking_number:),
        headers: build_headers,
        method: @conf.dig(:api, :methods, :documents)
      }

      save_request(request)
      request
    end

    def parse_document_response(_type, _tracking_number, response)
      DocumentResponse.new(content_type: response.headers['content-type'], data: response.body, request: last_request)
    end

    # Locations

    def build_locations_request
      request = {
        url: build_url(:locations),
        headers: build_headers,
        method: @conf.dig(:api, :methods, :locations)
      }

      save_request(request)
      request
    end

    def parse_locations_response(country:, response:)
      raise ResponseError, 'API Error: Unknown response' if response.blank?

      raise ResponseError, 'API Error: Unknown response' unless response.is_a?(Array)

      locations = response

      locations = locations.map do |location|
        Location.new(
          address1: location['address1'],
          city: location['city'],
          province: location['state'],
          country: ActiveUtils::Country.find(location['countrycd']),
          contact: Contact.new(fax: location['fax'], phone: location['phone'])
        )
      end

      locations.select { |location| location.country == country }
    end

    # Pickups

    def build_pickup_request(
      delivery_from:,
      delivery_to:,
      dispatcher:,
      pickup_from:,
      pickup_to:,
      scac:,
      service:,
      shipment:
    )
      pickup_accessorials, delivery_accessorials = build_accessorials(shipment.accessorials)

      dispatcher_phone = dispatcher.phone.delete('^0-9')
      shipper_phone = shipment.origin.contact.phone.delete('^0-9')
      receiver_phone = shipment.destination.contact.phone.delete('^0-9')

      api_credentials = credentials.find { |c| c.type == :api }

      declared_value = if shipment.declared_value_cents.blank?
                         '0'
                       else
                         format('%.2f', (shipment.declared_value_cents.to_f / 100).ceil)
                       end

      request = {
        headers: build_headers,
        method: @conf.dig(:api, :methods, :pickup),
        url: build_url(:pickup),
        body: {
          testmode: 'N',
          consignee: {
            consigneeAddress1: shipment.destination.address1,
            consigneeAddress2: '',
            consigneeCity: shipment.destination.city,
            consigneeCloseTime: delivery_to.strftime('%H:%M:00'),
            consigneeContactEmail: '',
            consigneeContactName: shipment.destination.contact.name || 'Receiving',
            consigneeContactPhone: receiver_phone || '',
            consigneeCountry: shipment.destination.country.code(:alpha2).value,
            consigneeLocationName: shipment.destination.contact.name,
            consigneeOpenTime: delivery_from.strftime('%H:%M:00'),
            consigneeState: shipment.destination.province,
            consigneeZipCode: shipment.destination.postal_code.to_s
          },
          shipper: {
            shipperAddress1: shipment.origin.address1,
            shipperAddress2: '',
            shipperCity: shipment.origin.city,
            shipperCloseTime: pickup_to.strftime('%H:%M:00'),
            shipperContactEmail: '',
            shipperContactName: shipment.origin.contact.name || 'Shipping',
            shipperContactPhone: shipper_phone || '',
            shipperCountry: shipment.origin.country.code(:alpha2).value,
            shipperLocationName: shipment.origin.contact.name,
            shipperOpenTime: pickup_from.strftime('%H:%M:00'),
            shipperState: shipment.origin.province,
            shipperZipCode: shipment.origin.postal_code.to_s
          },
          orderDetails: {
            airbillNumber: '00000000',
            billToCustomerNumber: api_credentials.account&.to_s || '',
            customerReferenceNumber: shipment.po_number,
            declaredValue: declared_value,
            description: shipment.packages.map(&:description).reject(&:blank?).uniq.join(', '),
            destinationAirportCode: '',
            guaranteedService: 'N',
            hazmat: shipment.hazmat? ? 'Y' : 'N',
            inBondShipment: declared_value.to_f.positive? ? 'Y' : 'N',
            orderAction: 'CREATE',
            originAirportCode: '',
            shippingDate: pickup_from.strftime('%Y-%m-%d'),
            shipperCustomerNumber: api_credentials.account&.to_s || '',
            specialInstructions: '',
            dimensions: {
              dimension: shipment.packages.map do |package|
                {
                  height: package.inches(:height).ceil.to_s,
                  length: package.inches(:length).ceil.to_s,
                  width: package.inches(:width).ceil.to_s,
                  pieces: package.quantity.to_s
                }
              end
            },
            freightDetails: { freightDetail: build_freight_details(shipment.packages) },
            delivery: {
              airportDelivery: delivery_accessorials&.include?('ALD') ? 'Y' : 'N',
              deliveryAccessorials: { deliveryAccessorial: delivery_accessorials }
            },
            emergencyContact: {
              email: dispatcher.email,
              name: dispatcher.name,
              phone: dispatcher_phone
            },
            pickup: {
              airportPickup: pickup_accessorials&.include?('ALP') ? 'Y' : 'N',
              pickupAccessorials: { pickupAccessorial: pickup_accessorials },
              pickupReadyTime: pickup_from.strftime('%H:%M:00')
            },
            referenceNumbers: {
              referenceNumber: [
                shipment.order_number,
                shipment.po_number,
                ''
              ]
            }
          }
        }.to_json
      }

      save_request(request)
      request
    end

    def parse_pickup_response(response)
      pickup_response = PickupResponse.new(request: last_request, response:)
      pickup_number = response['airbillNumber']

      if pickup_number.blank?
        pickup_response.error = Interstellar::ResponseError.new('Unknown response')
        return pickup_response
      end

      pickup_response.pickup_number = pickup_number
      pickup_response
    end

    # Rates

    def build_rate_request(shipment:)
      api_credentials = credentials.find { |c| c.type == :api }

      freight_details = build_freight_details(shipment.packages)
      dimensions = build_dimensions(shipment.packages)
      declared_value = if shipment.declared_value_cents.blank?
                         '0'
                       else
                         format('%.2f', (shipment.declared_value_cents.to_f / 100).ceil)
                       end
      pickup_accessorials, delivery_accessorials = build_accessorials(shipment.accessorials)

      request = {
        url: build_url(:rates),
        headers: build_headers,
        method: @conf.dig(:api, :methods, :rates),
        body: {
          billToCustomerNumber: api_credentials.account,
          origin: {
            originZipCode: shipment.origin.postal_code.to_s.upcase,
            pickup: {
              airportPickup: pickup_accessorials&.include?('ALP') ? 'Y' : 'N',
              pickupAccessorials: { pickupAccessorial: pickup_accessorials }
            }
          },
          destination: {
            destinationZipCode: shipment.destination.postal_code.to_s.upcase,
            delivery: {
              airportDelivery: delivery_accessorials&.include?('ALD') ? 'Y' : 'N',
              deliveryAccessorials: { deliveryAccessorial: delivery_accessorials }
            }
          },
          dimensions: { dimension: dimensions },
          freightDetails: { freightDetail: freight_details },
          hazmat: shipment.hazmat? ? 'Y' : 'N',
          inBondShipment: 'N',
          declaredValue: declared_value,
          shippingDate: Date.current.strftime('%Y-%m-%d')
        }.to_json
      }

      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:)
      rate_response = RateResponse.new(request: last_request, response:)

      if response.blank?
        rate_response.error = ResponseError.new('API Error: Unknown response')
        return rate_response
      end

      error = response.key?('errorMessage')

      unless error.blank?
        rate_response.error = ResponseError.new(error)
        return rate_response
      end

      if response['quoteTotal'].blank?
        rate_response.error = ResponseError.new('Cost is blank')
        return rate_response
      end

      transit_days = response['transitDaysTotal']

      charge_line_items = response.dig('chargeLineItems', 'chargeLineItem')
      prices = []

      charge_line_items.each do |charge_line_item|
        cents = (charge_line_item['amount'] * 100).to_i
        next if cents.zero?

        description = charge_line_item_description(charge_line_item)

        prices << Price.new(blame: :api, cents:, description:)
      end

      rate = Rate.new(
        carrier: self,
        carrier_name: self.class.name,
        currency: 'USD',
        scac: self.class.scac.upcase,
        service_name: :standard,
        shipment:,
        prices:,
        transit_days:,
        with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
      )

      rate_response.rates = [rate]
      rate_response
    end

    def charge_line_item_description(charge_line_item)
      description = charge_line_item['description'] || ''
      description = description.gsub('-', '')
      description = description.capitalize

      code = charge_line_item['code']&.upcase || ''
      description = "#{description} (#{code})" unless code.blank?
      description = description.gsub('Fsc', 'FSC') if description.include?('Fsc')

      description.squish
    end

    # Tracking

    def build_tracking_request(tracking_number)
      request = {
        url: build_url(:track, tracking_number:),
        headers: build_headers,
        method: @conf.dig(:api, :methods, :track),
        body: {
          billToCustomerNumber: api_credentials.account,
          referenceNumber: tracking_number.to_s
        }.to_json
      }

      save_request(request)
      request
    end

    def parse_api_date_time(date_time, location)
      return nil if date_time.blank?

      local_date_time = ::DateTime.strptime(date_time, '%m/%d/%y %H:%M').to_fs(:db)
      DateTime.new(local_date_time:, location:)
    end

    def parse_tracking_response(response)
      tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)

      actual_delivery_date = nil
      estimated_delivery_date = nil
      receiver_location = nil
      scheduled_delivery_date = nil
      ship_time = nil
      shipper_location = nil

      shipment_events = []

      api_events = response
      api_events.each do |api_event|
        event = nil
        @conf.dig(:events, :types).each do |key, val|
          if api_event['statusCode'].upcase == val
            event = key
            break
          end
        end
        next if event.blank?

        location = Location.new(
          city: api_event['city'].titleize,
          province: api_event['state'].upcase,
          postal_code: api_event['zip'].upcase,
          country: ActiveUtils::Country.find(api_event['country'])
        )

        date_time = parse_api_date_time(api_event['recordDate'], location)

        api_estimated_delivery_date = api_event['estimatedArrivalDate']
        estimated_delivery_date = parse_api_date_time(api_estimated_delivery_date, nil)

        case event
        when :delivered
          actual_delivery_date = date_time
          receiver_location = location
        when :delivery_appointment_scheduled
          api_date_time = api_event['scheduledDeliveryFromDate']
          scheduled_delivery_date = parse_api_date_time(api_date_time, location)
        when :picked_up
          ship_time = date_time
          shipper_location = location
        end

        shipment_events << ShipmentEvent.new(date_time:, location:, type_code: event)
      end

      estimated_delivery_date = scheduled_delivery_date unless scheduled_delivery_date.blank?

      status = shipment_events.last&.type_code

      tracking_number = api_events.last['airbillNumber']

      tracking_response.assign_attributes(
        actual_delivery_date:,
        destination: receiver_location,
        estimated_delivery_date:,
        origin: shipper_location,
        scheduled_delivery_date:,
        ship_time:,
        shipment_events:,
        status:,
        tracking_number:
      )

      tracking_response
    end
  end
end
