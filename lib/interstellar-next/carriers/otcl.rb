# frozen_string_literal: true

module Interstellar
  class OTCL < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'OnTrac'
    @@scac = 'OTCL'

    XML_HEADERS = {
      'Accept': 'application/xml',
      'charset': 'utf-8',
      'Content-Type': 'application/xml'
    }.freeze

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(150, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(6, :feet)
    end

    def overlength_fees_require_tariff?
      false
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

      serviceable_accessorials = @conf.dig(:accessorials, :mappable).keys +
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
      request = build_shipment_request(
        delivery_from:,
        delivery_to:,
        dispatcher:,
        pickup_from:,
        pickup_to:,
        scac:,
        service:,
        shipment:
      )

      labels = parse_shipment_response(commit(request))

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

    # Rates

    def find_rates(shipment:)
      validate_packages(shipment.packages)

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

    protected

    def build_url(action, options = {})
      env = @test_mode ? :test : :production

      url = "https://#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, env, action)}"
      url = url.gsub('%ACCOUNT_NUMBER%', @options[:account])

      url += "?pw=#{@options[:password]}"
      url << "&#{options[:params]}" unless options[:params].blank?

      url
    end

    def build_request(action, options = {})
      request = {
        url: build_url(action, options),
        headers: XML_HEADERS,
        method: @conf.dig(:api, :methods, action)
      }

      save_request(request)
      request
    end

    def commit(request)
      body = request[:body]
      headers = request[:headers]
      method = request[:method]
      url = request[:url]

      response = case method
                 when :post
                   HTTParty.post(url, headers:, body:, debug_output: $stdout)
                 else
                   HTTParty.get(url, headers:, debug_output: $stdout)
                 end

      pp 'Response'
      pp response
      pp 'parsed_response'
      pp response&.parsed_response

      response.parsed_response if response&.parsed_response
    end

    def serviceable_states?(states)
      valid_states = %w[AZ CA CO ID NV OR UT WA]

      invalid_states = []
      states.each do |state|
        invalid_states << state unless valid_states.include?(state)
      end

      return true if invalid_states.blank?

      raise Interstellar::UnserviceableError, "No service to #{invalid_states.join(', ')}"
    end

    # Documents

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

      dispatcher_phone = dispatcher.phone.sub('+1', '').delete('^0-9')
      shipper_phone = shipment.origin.contact.phone.sub('+1', '').delete('^0-9')
      receiver_phone = shipment.destination.contact.phone.sub('+1', '').delete('^0-9')

      declared_value = if shipment.declared_value_cents.blank?
                         '0'
                       else
                         format('%.2f', (shipment.declared_value_cents.to_f / 100).ceil)
                       end

      raise UnserviceableError, 'Palletized freight unsupported' unless shipment.loose?

      request_body = {
        'Address': shipment.origin.address1,
        'City': shipment.origin.city,
        'CloseAt': pickup_to.strftime('%H:%M:00'),
        'Contact': shipment.origin.contact.name || 'Shipping',
        'Date': pickup_from.to_date,
        'DelZip': shipment.destination.zip,
        'Instructions': '',
        'Name': shipment.origin.contact.company_name,
        'Phone': shipper_phone,
        'ReadyAt': pickup_from.strftime('%H:%M:00'),
        'State': shipment.origin.state,
        'Zip': shipment.origin.zip
      }.freeze

      request = {
        headers: XML_HEADERS,
        method: @conf.dig(:api, :methods, :pickups),
        url: build_url(:pickups),
        body: request_body.to_xml(root: 'OnTracPickupRequest', skip_types: true)
      }

      save_request(request)
      request
    end

    def build_shipment_request(
      delivery_from:,
      delivery_to:,
      dispatcher:,
      pickup_from:,
      pickup_to:,
      scac:,
      service:,
      shipment:
    )

      dispatcher_phone = dispatcher.phone.sub('+1', '').delete('^0-9')
      shipper_phone = shipment.origin.contact.phone.sub('+1', '').delete('^0-9')
      receiver_phone = shipment.destination.contact.phone.sub('+1', '').delete('^0-9')

      declared_value = if shipment.declared_value_cents.blank?
                         '0'
                       else
                         format('%.2f', (shipment.declared_value_cents.to_f / 100).ceil)
                       end

      raise UnserviceableError, 'Palletized freight unsupported' unless shipment.loose?

      base_api_shipment = {
        'consignee': {
          'Name': shipment.destination.contact.company_name,
          'Addr1': shipment.destination.address1,
          'Addr2': '',
          'Addr3': '',
          'City': shipment.destination.city,
          'Contact': shipment.destination.contact.name || 'Shipping',
          'Phone': receiver_phone || '',
          'State': shipment.destination.state,
          'Zip': shipment.destination.zip.to_s
        },
        'shipper': {
          'Name': shipment.origin.contact.company_name,
          'Addr1': shipment.origin.address1,
          'City': shipment.origin.city,
          'State': shipment.origin.state,
          'Zip': shipment.origin.zip,
          'Contact': shipment.origin.contact.name || 'Shipping',
          'Phone': shipper_phone
        },
        'BillTo': '0',
        'CargoType': '0',
        'COD': '0',
        'CODType': 'NONE',
        'Declared': declared_value,
        'DelEmail': dispatcher.email,
        'Instructions': '',
        'LabelType': '1', # PDF label
        'Reference': shipment.order_number,
        'Reference2': shipment.po_number,
        'Reference3': '',
        'Residential': shipment.accessorials.include?(:residential_delivery) ? 'true' : 'false',
        'SaturdayDel': 'false',
        'Service': 'C',
        'ShipDate': pickup_from.to_date.to_s,
        'ShipEmail': dispatcher.email,
        'SignatureRequired': 'true',
        'Tracking': ''
      }.freeze

      api_shipments = []

      shipment.packages.each do |package|
        package.quantity.times do
          api_shipments << base_api_shipment.merge(
            {
              'DIM': {
                'Length': package.length(:inches).ceil,
                'Width': package.width(:inches).ceil,
                'Height': package.height(:inches).ceil
              },
              'UID': SecureRandom.uuid,
              'Weight': package.pounds(:each).ceil
            }
          )
        end
      end

      request = {
        headers: XML_HEADERS,
        method: @conf.dig(:api, :methods, :shipments),
        url: build_url(:shipments),
        body: {
          'Shipments': api_shipments
        }.to_xml(root: 'OnTracShipmentRequest', skip_types: true)
      }

      save_request(request)
      request
    end

    def parse_pickup_response(response)
      raise Interstellar::ResponseError, 'API Error: Blank response' if response.blank?

      error = response.dig('OnTracPickupResponse', 'Error')

      unless error.blank?
        error = error.capitalize

        raise Interstellar::ResponseError, "API Error: #{error}"
      end

      response.dig('OnTracPickupResponse', 'Tracking')
    end

    def parse_shipment_response(response)
      raise Interstellar::ResponseError, 'API Error: Blank response' if response.blank?

      error = response.dig('OnTracRateResponse', 'Shipments', 'Error') ||
              response.dig('OnTracRateResponse', 'Shipments', 'Shipment', 'Error')

      unless error.blank?
        error = error.capitalize

        raise Interstellar::InvalidCredentialsError, error if error.downcase.include?('invalid username')

        raise Interstellar::UnserviceableError, error if error.downcase.include?('no valid service')

        raise Interstellar::UnserviceableError, error if error.downcase.include?('not serviced')

        raise Interstellar::ResponseError, "API Error: #{error}"
      end

      base64_labels = response.dig('OnTracShipmentResponse', 'Shipments', 'Shipment')&.map { |s| s['Label'] }
      raise Interstellar::ResponseError, 'API Error: Blank label' if base64_labels.blank?

      labels = []

      base64_labels.each do |base64_label|
        labels << Label.new(data: base64_label)
      end

      labels
    end

    # Rates

    def build_rate_request(shipment:)
      serviceable_accessorials?(shipment.accessorials)
      serviceable_states?([shipment.origin.state, shipment.destination.state])

      # API supports non-loose items (see below) but per OnTrac it shouldn't be quoted. We'll raise an error here but
      # leave the support baked-in below anyway.
      raise Interstellar::UnserviceableError, 'Palletized freight unsupported' unless shipment.loose?

      params = ''.dup
      params << 'packages='

      total_weight = shipment.packages.map { |p| p.pounds(:total) }.sum

      i = 1
      package_param_parts = []

      shipment.packages.each do |package|
        package.quantity.times do
          declared_value = if shipment.declared_value_cents.blank?
                             0
                           else
                             shipment.declared_value_cents.to_f * (package.pounds(:each) / total_weight)
                           end

          declared_value = declared_value.to_s
          service = shipment.palletized ? 'H' : 'C'

          parts = []

          parts << "ID#{i}"
          parts << shipment.origin.zip
          parts << shipment.destination.zip
          parts << shipment.accessorials.include?(:residential_delivery) ? 'true' : 'false'
          parts << '0'
          parts << 'false' # Staurday delivery
          parts << declared_value
          parts << package.pounds(:each)
          parts << "#{package.inches(:length).ceil}X#{package.inches(:width).ceil}X#{package.inches(:height).ceil}"
          parts << 'C'
          parts << '0' # not a letter
          parts << '0' # always 0 per documentation

          package_param_parts << parts.join(';')
        end
      end

      params << package_param_parts.join(',')

      build_request(:rates, { params: })
    end

    def parse_rate_response(shipment:, response:)
      raise Interstellar::ResponseError, 'API Error: Blank response' if response.blank?

      error = response.dig('OnTracRateResponse', 'Shipments', 'Error') ||
              response.dig('OnTracRateResponse', 'Shipments', 'Shipment', 'Error')

      unless error.blank?
        error = error.capitalize

        raise Interstellar::InvalidCredentialsError, error if error.downcase.include?('invalid username')

        raise Interstellar::UnserviceableError, error if error.downcase.include?('no valid service')

        raise Interstellar::UnserviceableError, error if error.downcase.include?('not serviced')

        raise Interstellar::ResponseError, "API Error: #{error}"
      end

      rate = response.dig('OnTracRateResponse', 'Shipments', 'Shipment', 'Rates', 'Rate')
      raise Interstellar::ResponseError, 'API Error: Blank response' if rate.blank?

      rate_estimates = []

      cost = rate['TotalCharge']&.to_f
      raise Interstellar::ResponseError, 'API Error: Cost is empty' if cost.blank?

      cost = (cost * 100).to_i
      transit_days = rate['TransitDays'].to_i
      service = case rate['Service']
                when 'C'
                when 'H'
                end
      :standard

      RateResponse.new(
        rates: [
          Rate.new(
            carrier: self,
            carrier_name: self.class.name,
            currency: 'USD',
            scac: self.class.scac.upcase,
            service_name: service,
            shipment:,
            total_price: cost,
            transit_days:,
            with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
          )
        ],
        request: last_request,
        response:
      )
    end

    # Tracking
  end
end
