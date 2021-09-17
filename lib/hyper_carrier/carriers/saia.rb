# frozen_string_literal: true

module HyperCarrier
  class SAIA < HyperCarrier::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Saia'
    @@scac = 'SAIA'

    # Documents

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
      request = build_tracking_request(tracking_number)
      parse_tracking_response(commit_soap(:track, request))
    end

    protected

    def commit_soap(action, request)
      Savon.client(
        wsdl: request_url(action),
        convert_request_keys_to: :none,
        env_namespace: :soap,
        element_form_default: :qualified
      ).call(
        @conf.dig(:api, :actions, action),
        message: request_blueprint.deep_merge(request)
      )&.body&.to_hash&.with_indifferent_access
    end

    def request_blueprint
      {
        'request': {
          'Application': 'ThirdParty',
          'AccountNumber': @options[:account],
          'UserID': @options[:username],
          'Password': @options[:password],
          'TestMode': @options[:debug].blank? ? 'N' : 'Y',
        }
      }
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
    end

    # Documents

    # Rates
    def build_rate_request(origin, destination, packages, options = {})
      options = @options.merge(options)

      accessorials = [
        { 'AccessorialItem': { 'Code': 'SingleShipment' } }
      ]
      unless options[:accessorials].blank?
        serviceable_accessorials?(options[:accessorials])
        options[:accessorials].each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << { 'AccessorialItem': { 'Code': @conf.dig(:accessorials, :mappable)[a] } }
          end
        end
      end

      excessive_length_total_inches = 0
      longest_dimension = packages.inject([]) { |_arr, p| [p.length(:in), p.width(:in)] }.max.ceil
      if longest_dimension >= 96
        accessorials << { 'AccessorialItem': { 'Code': 'ExcessiveLength' } }
        excessive_length_total_inches += longest_dimension
      end
      excessive_length_total_inches = excessive_length_total_inches.ceil.to_s

      accessorials = accessorials.uniq

      details = []
      dimensions = []
      packages.each do |package|
        details << {
          'DetailItem': {
            'Weight': package.pounds.ceil,
            'Class': package.freight_class.to_s,
            'Length': package.length(:in).ceil,
            'Width': package.width(:in).ceil,
            'Height': package.height(:in).ceil
          }
        }
        dimensions << {
          'DimensionItem': {
            'Units': 1,
            'Length': package.length(:in).round(2),
            'Width': package.width(:in).round(2),
            'Height': package.height(:in).round(2),
            'Type': 'IN' # inches
          }
        }
      end
      request = {
        'request': {
          'Application': 'ThirdParty',
          'BillingTerms': 'Prepaid',
          'OriginCity': origin.city,
          'OriginState': origin.state,
          'OriginZipcode': origin.to_hash[:postal_code].to_s.upcase,
          'DestinationCity': destination.city,
          'DestinationState': destination.state,
          'DestinationZipcode': destination.to_hash[:postal_code].to_s.upcase,
          'WeightUnits': 'LBS',
          'TotalCube': packages.inject(0) { |_sum, p| _sum += p.cubic_ft }.to_f.round(2),
          'TotalCubeUnits': 'CUFT', # cubic ft
          'ExcessiveLengthTotalInches': excessive_length_total_inches,
          'Details': details,
          'Dimensions': dimensions,
          'Accessorials': accessorials
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
        error = response.dig(:create_response, :create_result, :code)

        if !error.blank?
          success = false
          message = response.dig(:create_response, :create_result, :message)
        else
          response = response.dig(:create_response, :create_result)
          cost = response.dig(:total_invoice)
          if cost
            cost = cost.sub('.', '').to_i
            transit_days = response.dig(:standard_service_days).to_i
            estimate_reference = response.dig(:quote_number)

            rate_estimates = []
            rate_estimates << RateEstimate.new(
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

            [
              { guaranteed_ltl: response.dig(:guarantee_amount) },
              { guaranteed_ltl_am: response.dig(:guarantee_amount12pm) },
              { guaranteed_ltl_pm: response.dig(:guarantee_amount2pm) }
            ].each do |service|
              if !service.values[0] == '0' && !service.values[0].blank?
                cost = service.values[0].sub('.', '').to_i
                rate_estimates << RateEstimate.new(
                  origin,
                  destination,
                  { scac: self.class.scac.upcase, name: self.class.name },
                  service.keys[0],
                  delivery_range: delivery_range,
                  estimate_reference: estimate_reference,
                  total_cost: cost,
                  total_price: cost,
                  currency: 'USD',
                  with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
                )
              end
              rate_estimates
            end
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
      request = {
        'request': {
          'ProNumber': tracking_number
        }
      }
      save_request(request)
      request
    end

    def parse_datetime(datetime)
      datetime ? DateTime.strptime(datetime, '%Y-%m-%d %H:%M:%S')&.to_s(:db) : nil
    end

    def parse_tracking_response(response)
      if !response
        error = 'API Error: Unknown response'
      else
        error = response.dig(:get_by_pro_number_response, :get_by_pro_number_result, :code)
      end

      return HyperCarrier::ShipmentNotFound if error

      search_result = response.dig(:get_by_pro_number_response, :get_by_pro_number_result)

      shipper_address = Location.new(
        street: (
          search_result.dig(:shipper, :address1) || '' +
          " #{search_result.dig(:shipper, :address2) || ''}"
        ).squeeze.strip.titleize,
        city: search_result.dig(:shipper, :city)&.squeeze&.strip&.titleize,
        state: search_result.dig(:shipper, :state)&.strip&.upcase,
        postal_code: search_result.dig(:shipper, :zipcode)&.strip,
        country: ActiveUtils::Country.find('USA')
      )

      receiver_address = Location.new(
        street: (
          search_result.dig(:consignee, :address1) || '' +
          " #{search_result.dig(:consignee, :address2) || ''}"
        ).squeeze.strip.titleize,
        city: search_result.dig(:consignee, :city)&.squeeze&.strip&.titleize,
        state: search_result.dig(:consignee, :state)&.strip&.upcase,
        postal_code: search_result.dig(:consignee, :zipcode)&.strip,
        country: ActiveUtils::Country.find('USA')
      )

      actual_delivery_date = parse_datetime(search_result.dig(:delivery_date_time_arrive))&.to_date
      pickup_date = parse_datetime(search_result.dig(:pickup_date_time))&.to_date
      scheduled_delivery_date = nil # TODO: Set correctly
      tracking_number = search_result.dig(:pro_number)

      shipment_events = []

      api_events = search_result.dig(:history, :history_item)

      if api_events.blank?
        shipment_events << ShipmentEvent.new(
          :picked_up,
          pickup_date,
          shipper_address
        )
      else
        api_events.each do |api_event|
          event_key = nil
          comment = api_event.dig(:activity)
  
          @conf.dig(:events, :types).each do |key, val|
            if comment.downcase.include?(val)
              event_key = key
              break
            end
          end
          next if event_key.blank?
  
          location = Location.new(
            city: api_event.dig(:city)&.titleize,
            state: api_event.dig(:state)&.upcase,
            country: ActiveUtils::Country.find('USA')
          )
          datetime_without_time_zone = parse_datetime(api_event.dig(:activity_date_time))
  
          # status and type_code set automatically by ActiveFreight based on event
          shipment_events << ShipmentEvent.new(event_key, datetime_without_time_zone, location)
        end
      end

      shipment_events = shipment_events&.sort_by(&:time)

      TrackingResponse.new(
        true,
        shipment_events&.last&.status,
        response,
        carrier: "#{@@scac}, #{@@name}",
        hash: response,
        response: response,
        status: shipment_events&.last&.status,
        type_code: shipment_events&.last&.status,
        ship_time: pickup_date,
        scheduled_delivery_date: scheduled_delivery_date,
        actual_delivery_date: actual_delivery_date,
        delivery_signature: nil,
        shipment_events: shipment_events,
        shipper_address: shipper_address,
        origin: shipper_address,
        destination: receiver_address,
        tracking_number: tracking_number,
        request: last_request
      )
    end
  end
end
