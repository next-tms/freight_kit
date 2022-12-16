# frozen_string_literal: true

module Interstellar
  class TheGreatInformationFactory < Platform
    class << self
      def required_credential_types
        %i[api]
      end

      def requirements
        %i[credentials tariff]
      end

      def overlength_fees_require_tariff?
        true
      end
    end

    REACTIVE_FREIGHT_PLATFORM = true

    include Interstellar::Rateable
    include Interstellar::Trackable
    include Interstellar::Pickupable
    include Interstellar::Documentable

    protected

    def wrap_request(request)
      { 'arg0' => request }
    end

    def build_soap_header
      api_credentials = fetch_credential(:api)

      { username: api_credentials.username, password: api_credentials.password }
    end

    def commit(action, request)
      client_args = {
        wsdl: build_url(action),
        convert_request_keys_to: :upcase,
        env_namespace: :soapenv
      }

      call_args = {
        headers: { 'SOAPAction' => '""' },
        soap_action: false,
        message: request
      }

      ::Interstellar::SoapClient.new(
        carrier: self,
        action:,
        client_args:,
        call_args:,
        soap_operation: @conf.dig(:api, :actions, action)
      ).call
    end

    def parse_api_date(date)
      return nil if date.blank?

      local_date = ::Date.strptime(date, '%m/%d/%Y')
      DateTime.new(local_date:)
    end

    def parse_api_date_time(date_time, location)
      return nil if date_time.blank?

      format = date_time.include?('-') ? '%Y-%m-%d %H:%M' : '%m/%d/%Y %H:%M'

      local_date_time = ::DateTime.strptime(date_time, format).to_fs(:db)
      DateTime.new(local_date_time:, location:)
    end

    def build_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      domain = @conf.dig(:api, :domains, action).presence || @conf.dig(:api, :domain)
      port = @conf.dig(:api, :ports, action)
      return [scheme, domain, @conf.dig(:api, :endpoints, action)].join unless port

      "#{scheme}#{domain}:#{port}#{@conf.dig(:api, :endpoints, action)}"
    end

    def strip_date(str)
      str ? str.split(/[A|P]M /)[1] : nil
    end

    # Rates

    def build_rate_request(shipment:)
      accessorials = []

      unless shipment.accessorials.blank?
        serviceable_accessorials?(shipment.accessorials)
        shipment.accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << { code: @conf.dig(:accessorials, :mappable)[a] }
          end
        end
      end

      accessorials = accessorials.uniq.to_a

      items = []
      shipment.packages.each do |package|
        items << {
          _class: package.freight_class,
          description: (package.description || 'Freight')[..8].upcase,
          haz: (package.hazmat? ? 'Y' : ''),
          pallets: (package.packaging.pallet? ? package.quantity : 0),
          pieces: package.quantity,
          weight: package.pounds(:total).ceil
        }
      end

      request = {
        securityinfo: build_soap_header,
        quote: {
          iam: 'D', # S for shipper, C for consignee, D for third party
          shipper: {
            city: shipment.origin.city.upcase,
            state: shipment.origin.province.upcase,
            zip: shipment.origin.postal_code.gsub(/\s+/, '').upcase
          },
          consignee: {
            city: shipment.destination.city.upcase,
            state: shipment.destination.province.upcase,
            zip: shipment.destination.postal_code.gsub(/\s+/, '').upcase
          },
          accessorialcount: shipment.accessorials.size,
          accessorial: shipment.accessorials.blank? ? [] : accessorials,
          ppdcol: 'P', # Prepaid
          itemcount: shipment.packages.size,
          item: items
        }
      }

      request = wrap_request(request)
      save_request(request)

      request
    end

    def rate_item_description(rate_item)
      description = rate_item[:description] || ''
      description = description.gsub('-', '')
      description = description.squish
      description = description.sub('disc.on', 'discount on')
      description = description.capitalize
      description = description.sub('zip code', 'ZIP code')
      description.sub('Zip code', 'ZIP code')
    end

    def parse_rate_response(shipment:, response:)
      rate_response = RateResponse.new(request: last_request, response:)

      if response.blank?
        rate_response.error = ResponseError.new('Unknown response')
        return rate_response
      end

      error_code = response.dig(:getquote_response, :return, :rating, :errorcode)
      if error_code
        rate_response.error = parse_error_response(error_code)
        return rate_response
      end

      total_cents = response.dig(:getquote_response, :return, :rating, :amount)

      raise Interstellar::ResponseError, 'API Error: Cost is empty' if total_cents.blank?

      rate_items = response.dig(:getquote_response, :return, :rateitem)
      total_cents = (total_cents.to_f * 100).to_i

      prices = []

      # Confusing API sometimes returns lines of freight with high costs and then later includes includes lines that
      # override the high cost without adding a discount, etc
      rate_items.each do |rate_item|
        next if ['Sub Total', 'GrandTotal'].include?(rate_item[:acccode])

        # Exclude lines that are just the packages repeated back to us
        next unless rate_item[:pallets] == '0' && rate_item[:pieces] == '0'

        cents = (rate_item[:amount].to_f * 100).to_i
        description = rate_item_description(rate_item)

        prices << Price.new(blame: :api, cents:, description:)
      end

      # Since we expected the low-cost overriding lines earlier, we need to handle situations where those lines do not
      # appear
      if prices.sum(&:cents) < total_cents
        prices = [
          Price.new(
            blame: :api,
            cents: total_cents - prices.sum(&:cents),
            description: 'Freight'
          )
        ] + prices
      end

      shipment.packages.each do |package|
        cents = overlength_fee(tariff, package)
        next unless cents.positive?

        prices << Price.new(
          blame: :tariff,
          cents:,
          description: 'Overlength fee'
        )
      end

      transit_days = response.dig(
        :getquote_response,
        :return,
        :service,
        :days
      ).to_i

      # Calculate real transit time based on information we have about the destination service days
      %i[mon tue wed thu fri].each do |weekday|
        transit_days += 1 if response.dig(:getquote_response, :return, :service, :destination, weekday) == 'N'
      end

      estimate_reference = response.dig(
        :getquote_response,
        :return,
        :rating,
        :quotenumber
      )

      rate = Rate.new(
        carrier_name: self.class.name,
        carrier: self,
        currency: 'USD',
        estimate_reference:,
        prices:,
        scac: self.class.scac.upcase,
        service_name: :standard,
        shipment:,
        transit_days:,
        with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
      )

      rate_response.rates = [rate]
      rate_response
    end

    # Tracking

    def build_tracking_request(tracking_number)
      request = { pronumber: tracking_number, securityinfo: build_soap_header }

      request = wrap_request(request)
      save_request(request)

      request
    end

    def parse_location(code)
      country = ActiveUtils::Country.find('USA')
      return Location.new(country:) unless code

      location = @conf.dig(:events, :locations, code.to_sym)

      if location
        Location.new(
          city: location[:city],
          province: location[:state],
          country:
        )
      else
        Location.new(city: code, country:)
      end
    end

    def parse_error_response(error_code)
      case error_code
      when 'BADUSRPWD' then InvalidCredentialsError.new
      when 'NOSVC' then UnserviceableError.new('Origin or destination has no service available')
      when 'BADCONZIP' then UnserviceableError.new('Invalid destination ZIP code')
      else
        ResponseError.new("API error code #{error_code}")
      end
    end

    def build_location(city, province)
      Location.new(city: city.titleize, province: province.upcase, country: ActiveUtils::Country.find('USA'))
    end

    def parse_tracking_response(response)
      tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)
      mapped_response = response.dig(:tracktrace_response, :return, :currentstatus)

      if mapped_response[:errorcode]
        tracking_response.error = parse_error_response(mapped_response[:errorcode])
        return tracking_response
      end

      receiver_location = build_location(mapped_response.dig(:consignee, :city),
                                         mapped_response.dig(:consignee, :state))
      shipper_location = build_location(mapped_response.dig(:shipper, :city), mapped_response.dig(:shipper, :state))

      actual_delivery_date = mapped_response[:deliverydate]

      unless actual_delivery_date.blank?
        comment = mapped_response[:status].downcase

        if comment.starts_with?('delivered')
          api_date = comment.downcase.split('signed')[0].split('on')[1].strip.sub('at ', '')
          actual_delivery_date = parse_api_date(api_date)
        end
      end

      shipment_events = []

      ship_time = parse_api_date(mapped_response[:shipdate])
      # Leave this open for modification later
      picked_up_event = ShipmentEvent.new(location: shipper_location, date_time: ship_time, type_code: :picked_up)

      scheduled_delivery_date = parse_api_date(mapped_response[:estdeliverydate])
      tracking_number = response.dig(:tracktrace_response, :return, :pronumber)

      api_events = response.dig(:tracktrace_response, :return, :history)
      api_events = [api_events] if api_events.is_a?(Hash)

      api_events.each_with_index do |api_event, index|
        event = nil
        @conf.dig(:events, :types).each do |key, val|
          if api_event[:description].downcase.include? val
            event = key
            break
          end
        end
        next if event.blank?

        location = if api_event[:location].blank?
                     case event
                     when :picked_up, :pickup_information_sent_to_carrier
                       shipper_location
                     when :delivered, :out_for_delivery
                       receiver_location
                     end
                   else
                     parse_location(api_event[:location])
                   end

        api_date_time = "#{api_event[:date]} #{api_event[:time]}"
        date_time = parse_api_date_time(api_date_time, location)

        case event
        when :arrived_at_terminal
          # Duplicate event occurs without location data from API
          break if api_event[:location].blank?
        when :delivered
          actual_delivery_date = date_time
        when :out_for_delivery
          # Do not consider out for delivery when out for delivery and interlined dates match
          next_api_event = api_events[index + 1]

          break if next_api_event.blank?

          if next_api_event[:description].include?('INTERLINE') && next_api_event[:date] == api_event[:date]
            shipment_events << ShipmentEvent.new(date_time:, location:, type_code: :departed)
            next
          end
        when :pickup_information_sent_to_carrier
          # Pickup event appears after carrier information sent, let's fix that
          picked_up_event.date_time = date_time.dup
        end

        shipment_events << ShipmentEvent.new(date_time:, location:, type_code: event)
      end

      shipment_events << picked_up_event

      shipment_events = shipment_events.sort_by do |shipment_event|
        d = shipment_event.date_time
        d&.local_date_time || d.date_time_with_zone&.to_fs(:db) || d.local_date&.to_fs(:db)
      end

      status = shipment_events.last&.type_code

      # Workarounds for false status on certain events when timestamps are in wrong order
      status = :out_for_delivery if shipment_events.find do |shipment_event|
                                      shipment_event.type_code == :out_for_delivery
                                    end
      status = :delivered if shipment_events.find { |shipment_event| shipment_event.type_code == :delivered }

      tracking_response.assign_attributes(
        actual_delivery_date:,
        destination: receiver_location,
        origin: shipper_location,
        scheduled_delivery_date:,
        ship_time:,
        shipment_events:,
        status:,
        tracking_number:
      )

      tracking_response
    end

    def parse_pickup_response(response)
      pickup_response = PickupResponse.new(request: last_request, response:)

      result = response.dig(:requestpickup_response, :return, :results)
      if result[:errorcode]
        pickup_response.error = Interstellar::ResponseError.new("API Error: #{result[:errorcode]}")
        return pickup_response
      end

      pickup_number = result[:pickupnumber]

      if pickup_number == '0'
        pickup_response.error = Interstellar::ResponseError.new('Unknown Error')
        return pickup_response
      end

      pickup_response.pickup_number = pickup_number
      pickup_response
    end

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

      shipper_phone = shipment.origin.contact.phone.gsub(/\s+/, '').gsub(/[()-+.]/, '')
      shipper_phone = shipper_phone[1..] if shipper_phone.length == 11

      request = {
        securityinfo: build_soap_header,
        shipperinfo: {
          name: shipment.origin.contact.company_name,
          contact: shipment.origin.contact.name,
          phonenumber: shipper_phone,
          address1: shipment.origin.address1,
          address2: shipment.origin.address2,
          city: shipment.origin.city,
          state: shipment.origin.province,
          ReadyDate: Date.today.strftime('%m/%d/%Y'),
          ReadyTime: pickup_from.strftime('%H%M').to_i,
          CloseTime: pickup_to.strftime('%H%M').to_i,
          zip: shipment.origin.postal_code,
          SpecialInstructions: ''
        },
        ShipmentCount: 1,
        shipments: [
          {
            DestZip: shipment.destination.postal_code,
            Pieces: shipment.packages.sum(&:quantity),
            Pallets: shipment.packages.select { |p| p.packaging.pallet? }.sum(&:quantity),
            Weight: shipment.packages.sum { |p| p.pounds(:total).ceil },
            HAZ: shipment.packages.any?(&:hazmat?) ? 'Y' : 'N',
            dblStack: 'N',
            SortSeg: 'N',
            Pro: shipment.pro,
            Liftgate: shipment.accessorials.include?(:liftgate_pickup) ? 'Y' : 'N'
          }
        ]
      }

      request = wrap_request(request)
      save_request(request)

      request
    end

    def parse_document_response(type, tracking_number)
      base_url = build_url(type)
      website_credentials = fetch_credential(:api)
      query_parameter = "&username=#{website_credentials.username}&" \
                        "password=#{website_credentials.password}&" \
                        "pronumber=#{tracking_number}&" \
                        'format=PDF'

      url = [base_url, query_parameter].join

      response = HTTParty.get(url)
      base64_document_data = response.deep_symbolize_keys.dig(:ImageRequest, :Image, :ImageData, :__content__)

      document_response = DocumentResponse.new(request: url)

      unless base64_document_data
        document_response.error = DocumentNotFoundError.new
        return document_response
      end

      decoded_pdf_data = Base64.decode64 base64_document_data
      document_response.assign_attributes(content_type: 'application/pdf', data: decoded_pdf_data)

      document_response
    end
  end
end
