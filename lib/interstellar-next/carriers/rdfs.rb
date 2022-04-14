# frozen_string_literal: true

module Interstellar
  class RDFS < Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Roadrunner Transportation Services'
    @@scac = 'RRDS'

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(10_000, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(8, :feet)
    end

    def overlength_fees_require_tariff?
      false
    end

    def requirements
      %i[username password account]
    end

    # Documents

    def pod(tracking_number)
      parse_document_response(:pod, tracking_number)
    end

    def pod_implemented?
      true
    end

    def scanned_bol(tracking_number)
      parse_document_response(:bol, tracking_number)
    end

    def scanned_bol_implemented?
      true
    end

    # Pickups

    def pickup_number_is_tracking_number?
      false
    end

    # Rates

    def find_rates(shipment:)
      begin
        validate_packages(shipment.packages)
      rescue UnserviceableError => e
        return RateResponse.new(error: e)
      end

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit_soap(:rates, request))
    end

    def find_rates_implemented?
      true
    end

    # Tracking

    def find_tracking_info(tracking_number)
      response = commit_tracking_request(tracking_number)

      parse_tracking_response(response)
    end

    def find_tracking_info_implemented?
      true
    end

    def find_tracking_number_from_pickup_number(pickup_number, _date, options = {})
      options = @options.merge(options)
      parse_tracking_number_from_pickup_number_response(pickup_number, options)
    end

    def find_tracking_number_from_pickup_number_implemented?
      true
    end

    protected

    def build_soap_header(action)
      {
        authentication_header: {
          :@xmlns => @conf.dig(:api, :soap, :namespaces, action),
          :user_name => @options[:username],
          :password => @options[:password]
        }
      }
    end

    def commit_soap(action, request)
      Savon.client(
        wsdl: request_url(action),
        convert_request_keys_to: :camelcase,
        env_namespace: :soap,
        element_form_default: :qualified
      ).call(
        @conf.dig(:api, :actions, action),
        soap_header: build_soap_header(action),
        message: request
      ).body
    rescue Savon::SOAPFault => e
      error = e.to_hash.dig(:fault, :detail, :error, :error_message)

      { error: }
    end

    def parse_amount(amount)
      negative = amount.start_with?('-$') || amount.start_with?('-')

      %w[$ - ,].each do |char|
        amount = amount.sub(char, '')
      end

      return 0 if amount.blank?

      amount = (amount.to_f * 100).to_i
      return amount unless negative

      amount * -1
    end

    def parse_api_date_time(date_time, location)
      return nil if date_time.blank? || date_time == '0001-01-01T00:00:00'

      local_date_time = ::DateTime.strptime(date_time, '%Y-%m-%dT%H:%M:%S').to_fs(:db)
      DateTime.new(local_date_time:, location:)
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domains, action)}#{@conf.dig(:api, :endpoints, action)}"
    end

    def strip_date(str)
      str ? str.split(/[A|P]M /)[1] : nil
    end

    # Documents

    def parse_document_response(type, tracking_number)
      url = request_url(type).sub('%%TRACKING_NUMBER%%', tracking_number.to_s)
      document_response = DocumentResponse.new(request: url)

      begin
        doc = Nokogiri::HTML(URI.parse(url).open)
      rescue OpenURI::HTTPError
        document_response.error = Interstellar::DocumentNotFoundError.new
        return document_response
      end

      data = Base64.decode64(doc.css('img').first['src'].split('data:image/jpg;base64,').last)

      document_response.assign_attributes(content_type: 'image/jpeg', data:)
      document_response
    end

    # Rates

    def build_rate_request(shipment:)
      service_delivery_options = [
        # API calls this invalid now
        # service_options: { service_code: 'SS' }
      ]

      unless shipment.accessorials.blank?
        serviceable_accessorials?(shipment.accessorials)
        shipment.accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            service_delivery_options << { service_options: { service_code: @conf.dig(:accessorials, :mappable)[a] } }
          end
        end
      end

      shipment.packages.each do |package|
        longest_dimension = [package.width(:inches), package.length(:inches)].max.ceil

        next unless longest_dimension > 96

        package.quantity.times do
          if longest_dimension > 144
            service_delivery_options << { service_options: { service_code: 'EXL' } }
          elsif longest_dimension > 96
            service_delivery_options << { service_options: { service_code: 'EXM' } }
          end
        end
      end

      shipment_detail = []
      shipment_box_count = 0
      shipment_pallet_count = 0

      shipment.packages.each do |package|
        if package.packaging.type == 'pallet'
          shipment_pallet_count += package.quantity
        else
          shipment_box_count += package.quantity
        end

        package.quantity.times do
          shipment_detail << {
            'ActualClass' => package.freight_class,
            'Weight' => package.pounds(:each).ceil
          }
        end
      end

      request = {
        'request' => {
          account: @options[:account],
          destination_zip: shipment.destination.zip.gsub(/\s+/, '').upcase,
          # :linear_feet => linear_ft(packages),
          origin_type: 'B', # O for shipper, I for consignee, B for third party
          origin_zip: shipment.origin.zip.gsub(/\s+/, '').upcase,
          pallet_count: shipment_pallet_count,
          payment_type: 'P', # prepaid
          pieces: shipment_box_count,
          service_delivery_options:,
          shipment_details: { shipment_detail: }
        }
      }

      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:)
      rate_response = RateResponse.new(request: last_request, response:)

      if response.blank?
        rate_response.error = ResponseError.new('Unknown response')
        return rate_response
      end

      unless response[:error].blank?
        ['no standard service', 'not in the standard pickup area'].each do |message|
          if response[:error].downcase.include?(message)
            rate_response.error = UnserviceableError.new(response[:error])
            return rate_response
          end
        end

        rate_response.error = ResponseError.new(response[:error])
        return rate_response
      end

      result = response.dig(:rate_quote_by_account_response, :rate_quote_by_account_result)

      if result[:net_charge].blank?
        rate_response.error = ResponseError.new('Cost is empty')
        return rate_response
      end

      estimate_reference = result.dig(:quote_number)
      rate_details = result.dig(:rate_details, :quote_detail)
      transit_days = result.dig(:routing_info, :estimated_transit_days).to_i

      prices = []

      rate_details.each do |rate_detail|
        if rate_detail[:description].blank?
          prices << Price.new(
            blame: :api,
            cents: parse_amount(rate_detail[:charge]),
            description: 'Freight'
          )

          next
        end

        prices << Interstellar::Price.new(
          blame: :api,
          cents: parse_amount(rate_detail[:charge]),
          description: rate_detail[:description]&.capitalize
        )
      end

      rate = Rate.new(
        carrier: self,
        carrier_name: self.class.name,
        currency: 'USD',
        estimate_reference:,
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

    # Tracking

    def commit_tracking_request(tracking_number)
      uri = URI.parse("#{request_url(:track)}/#{tracking_number}")
      save_request(uri)

      uri.open
    end

    def parse_api_location(comment, delimiters)
      return nil if comment.blank? || !comment.include?(delimiters[0])

      parts = if delimiters.size == 2
                comment.split(delimiters[0])[0].split(delimiters[1])[1].split(',')
              else
                comment.split(delimiters[0])[1].split(',')
              end

      if parts.size == 1
        str = parts[0].downcase
        if str.include?('long beach')
          return Location.new(
            city: 'Long Beach',
            province: 'CA',
            country: ActiveUtils::Country.find('USA')
          )
        end

        return nil
      end

      city = parts[0].squish.strip.titleize
      province = parts[1].gsub('.', '').squish.strip.upcase
      country = ActiveUtils::Country.find('USA')

      Location.new(city:, province:, country:)
    end

    def parse_tracking_response(response)
      tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)

      json = JSON.parse(response&.read || '{}')

      if json['SearchResults'].blank? || response.status[0] != '200'
        tracking_response.error = ShipmentNotFoundError.new
        return tracking_response
      end

      search_result = json['SearchResults']&.first

      pro = search_result.dig('Shipment', 'ProNumber')&.downcase
      if pro.blank? || pro.downcase.include?('not available')
        tracking_response.error = ShipmentNotFoundError.new
        return tracking_response
      end

      receiver_location = Location.new(
        city: search_result.dig('Shipment', 'Consignee', 'City').titleize,
        province: search_result.dig('Shipment', 'Consignee', 'State').upcase,
        country: ActiveUtils::Country.find('USA')
      )

      shipper_location = Location.new(
        city: search_result.dig('Shipment', 'Origin', 'City').titleize,
        province: search_result.dig('Shipment', 'Origin', 'State').upcase,
        country: ActiveUtils::Country.find('USA')
      )

      api_date_time = search_result.dig('Shipment', 'DeliveredDateTime')
      actual_delivery_date = parse_api_date_time(api_date_time, receiver_location)

      api_date_time = search_result.dig('Shipment', 'ApptDateTime')
      scheduled_delivery_date = parse_api_date_time(api_date_time, receiver_location)

      tracking_number = search_result.dig('Shipment', 'SearchItem')

      api_date_time = search_result.dig('Shipment', 'ProDateTime')
      ship_time = parse_api_date_time(api_date_time, shipper_location)

      last_location = nil
      shipment_events = []

      search_result.dig('Shipment', 'Comments').each do |api_event|
        type_code = api_event['ActivityCode']
        next if !type_code || type_code == 'ARQ'

        event = @conf.dig(:events, :types).key(type_code)
        next if event.blank?

        comment = strip_date(api_event['StatusComment'])

        location = case event
                   when :arrived_at_terminal
                     parse_api_location(comment, [' terminal in '])
                   when :delayed_due_to_weather
                     last_location
                   when :delivered
                     receiver_location
                   when :delivery_appointment_scheduled
                     last_location
                   when :departed
                     parse_api_location(comment, [' to ', 'from '])
                   when :located
                     parse_api_location(comment, [' currently at '])
                   when :out_for_delivery
                     parse_api_location(comment, [' to ', 'from '])
                   when :picked_up
                     shipper_location
                   when :pending_delivery_appointment
                     last_location
                   when :trailer_closed
                     last_location
                   when :trailer_unloaded
                     parse_api_location(comment, [' terminal in '])
                   end

        date_time = parse_api_date_time(api_event['StatusDateTime'], location)

        last_location = location

        shipment_events << ShipmentEvent.new(date_time:, location:, type_code: event)
      end

      status = shipment_events.last&.type_code

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

    def parse_tracking_number_from_pickup_number_response(pickup_number, _date, options = {})
      options = @options.merge(options)

      url = request_url(:tracking_number_from_pickup_number).sub('%%PICKUP_NUMBER%%', pickup_number.to_s)

      begin
        doc = Nokogiri::HTML(URI.parse(url).open)
      rescue OpenURI::HTTPError
        raise Interstellar::ShipmentNotFoundError, "API Error: #{@@name}: Shipment not found"
      end

      pro = doc.css('#lblProNumber')&.text

      if pro.blank? || pro.downcase.include?('not available')
        raise Interstellar::ShipmentNotFoundError, "API Error: #{@@name}: Shipment not found"
      end

      pro
    end
  end
end
