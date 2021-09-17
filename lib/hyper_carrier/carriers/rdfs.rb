# frozen_string_literal: true

module HyperCarrier
  class RDFS < Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Roadrunner Transportation Services'
    @@scac = 'RRDS'

    def requirements
      %i[username password account]
    end

    # Documents
    def find_bol(tracking_number, options = {})
      options = @options.merge(options)
      parse_document_response(:bol, tracking_number, options)
    end

    def find_pod(tracking_number, options = {})
      options = @options.merge(options)
      parse_document_response(:pod, tracking_number, options)
    end

    # Rates
    def find_rates(origin, destination, packages, options = {})
      options = @options.merge(options)
      origin = Location.from(origin)
      destination = Location.from(destination)
      packages = Array(packages)

      request = build_rate_request(origin, destination, packages, options)
      parse_rate_response(origin, destination, commit_soap(:rates, request))
    end

    # Tracking
    def find_tracking_info(tracking_number)
      tracking_request = build_tracking_request(tracking_number)
      parse_tracking_response(tracking_request)
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
      ).body.to_json
    end

    def parse_date(date)
      date ? DateTime.strptime(date, '%Y-%m-%dT%H:%M:%S').to_s(:db) : nil
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domains, action)}#{@conf.dig(:api, :endpoints, action)}"
    end

    def strip_date(str)
      str ? str.split(/[A|P]M /)[1] : nil
    end

    # Documents
    def parse_document_response(type, tracking_number, options = {})
      url = request_url(type).sub('%%TRACKING_NUMBER%%', tracking_number.to_s)

      begin
        doc = Nokogiri::HTML(URI.parse(url).open)
      rescue OpenURI::HTTPError
        return HyperCarrier::DocumentNotFound, "API Error: #{@@name}: Document not found"
      end

      data = Base64.decode64(doc.css('img').first['src'].split('data:image/jpg;base64,').last)
      path = if options[:path].blank?
               File.join(Dir.tmpdir, "#{@@name} #{tracking_number} #{type.to_s.upcase}.pdf")
             else
               options[:path]
             end

      file = Tempfile.new(binmode: true)
      file.write(data)
      file = Magick::ImageList.new(file.path)
      file.write(path)
      File.exist?(path) ? path : false
    end

    # Rates
    def build_rate_request(origin, destination, packages, options = {})
      options = @options.merge(options)

      service_delivery_options = [
        # API calls this invalid now
        # service_options: { service_code: 'SS' }
      ]

      unless options[:accessorials].blank?
        serviceable_accessorials?(options[:accessorials])
        options[:accessorials].each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            service_delivery_options << { service_options: { service_code: @conf.dig(:accessorials, :mappable)[a] } }
          end
        end
      end

      longest_dimension = packages.inject([]) { |_arr, p| [p.length(:in), p.width(:in)] }.max.ceil
      if longest_dimension > 144
        service_delivery_options << { service_options: { service_code: 'EXL' } }
      elsif longest_dimension > 96
        service_delivery_options << { service_options: { service_code: 'EXM' } }
      end

      service_delivery_options = service_delivery_options.uniq.to_a

      request = {
        'request' => {
          origin_zip: origin.to_hash[:postal_code].to_s,
          destination_zip: destination.to_hash[:postal_code].to_s,
          shipment_details: {
            shipment_detail: packages.inject([]) do |arr, package|
              arr << {
                'ActualClass' => package.freight_class,
                'Weight' => package.pounds.ceil
              }
            end
          },
          service_delivery_options: service_delivery_options,
          origin_type: options[:origin_type] || 'B', # O for shipper, I for consignee, B for third party
          payment_type: options[:payment_type] || 'P', # Prepaid
          pallet_count: packages.size,
          # :linear_feet => linear_ft(packages),
          pieces: packages.size,
          account: options[:account]
        }
      }

      save_request(request)
      request
    end

    def parse_rate_response(origin, destination, response)
      success = true
      message = ''

      if !response
        success = false
        message = 'API Error: Unknown response'
      else
        response = JSON.parse(response)
        if response[:error]
          success = false
          message = response[:error]
        else
          cost = response.dig('rate_quote_by_account_response', 'rate_quote_by_account_result', 'net_charge')
          transit_days = response.dig(
            'rate_quote_by_account_response',
            'rate_quote_by_account_result',
            'routing_info',
            'estimated_transit_days'
          ).to_i
          estimate_reference = response.dig(
            'rate_quote_by_account_response',
            'rate_quote_by_account_result',
            'quote_number'
          )
          if cost
            cost = (cost.to_f * 100).to_i
            rate_estimates = [
              RateEstimate.new(
                origin,
                destination,
                { scac: self.class.scac.upcase, name: self.class.name },
                :standard,
                transit_days: transit_days,
                estimate_reference: estimate_reference,
                total_cost: cost,
                total_price: cost,
                currency: 'USD',
                with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
              )
            ]
          else
            success = false
            message = 'API Error: Cost is emtpy'
          end
        end
      end

      RateResponse.new(
        success,
        message,
        response.to_hash,
        rates: rate_estimates,
        response: response,
        request: last_request
      )
    end

    # Tracking
    def build_tracking_request(tracking_number)
      URI.parse("#{request_url(:track)}/#{tracking_number}").open
    end

    def parse_location(comment, delimiters)
      return nil if comment.blank? || !comment.include?(delimiters[0]) || !comment.include?(delimiters[1])
      parts = comment.split(delimiters[0])[0].split(delimiters[1])[1].split(',')

      city = parts[0].squeeze.strip.titleize
      state = parts[1].squeeze.strip.upcase

      Location.new(
        city: city,
        province: state,
        state: state,
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_tracking_response(response)
      json = JSON.parse(response&.read || '{}')

      return HyperCarrier::ShipmentNotFound if json.dig('SearchResults').blank? || response.status[0] != '200'

      search_result = json.dig('SearchResults')[0]
      if search_result.dig('Shipment', 'ProNumber').downcase.include?('not available')
        return HyperCarrier::DocumentNotFound
      end

      receiver_address = Location.new(
        city: search_result.dig('Shipment', 'Consignee', 'City').titleize,
        province: search_result.dig('Shipment', 'Consignee', 'State').upcase,
        state: search_result.dig('Shipment', 'Consignee', 'State').upcase,
        country: ActiveUtils::Country.find('USA')
      )

      shipper_address = Location.new(
        city: search_result.dig('Shipment', 'Origin', 'City').titleize,
        province: search_result.dig('Shipment', 'Origin', 'State').upcase,
        state: search_result.dig('Shipment', 'Origin', 'State').upcase,
        country: ActiveUtils::Country.find('USA')
      )

      actual_delivery_date = parse_date(search_result.dig('Shipment', 'DeliveredDateTime'))
      scheduled_delivery_date = parse_date(search_result.dig('Shipment', 'ApptDateTime'))
      tracking_number = search_result.dig('Shipment', 'SearchItem')

      last_location = nil
      shipment_events = []
      search_result.dig('Shipment', 'Comments').each do |api_event|
        type_code = api_event.dig('ActivityCode')
        next if !type_code || type_code == 'ARQ'

        event = @conf.dig(:events, :types).key(type_code)
        next if event.blank?

        datetime_without_time_zone = parse_date(api_event.dig('StatusDateTime'))
        comment = strip_date(api_event.dig('StatusComment'))

        case event
        when :arrived_at_terminal
          location = parse_location(comment, [' to ', 'in '])
        when :delivered
          location = receiver_address
        when :departed
          location = parse_location(comment, [' to ', 'from '])
        when :out_for_delivery
          location = parse_location(comment, [' to ', 'from '])
        when :picked_up
          location = shipper_address
        when :trailer_closed
          location = last_location
        when :trailer_unloaded
          location = parse_location(comment, [' to ', 'in '])
        end
        last_location = location

        # status and type_code set automatically by ActiveFreight based on event
        shipment_events << ShipmentEvent.new(event, datetime_without_time_zone, location)
      end

      shipment_events = shipment_events.sort_by(&:time)

      TrackingResponse.new(
        true,
        shipment_events.last&.status,
        json,
        carrier: "#{@@scac}, #{@@name}",
        json: json,
        response: response,
        status: shipment_events.last&.status,
        type_code: shipment_events.last&.status,
        ship_time: parse_date(search_result.dig('Shipment', 'ProDateTime')),
        scheduled_delivery_date: scheduled_delivery_date,
        actual_delivery_date: actual_delivery_date,
        delivery_signature: nil,
        shipment_events: shipment_events,
        shipper_address: shipper_address,
        origin: shipper_address,
        destination: receiver_address,
        tracking_number: tracking_number
      )
    end
  end
end
