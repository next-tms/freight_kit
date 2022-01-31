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

      commit(request)
      # parse_pickup_response(commit(request))
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

    def find_tracking_info(tracking_number, *)
      request = build_tracking_request(tracking_number)
      parse_tracking_response(commit(request))
    end

    def find_tracking_info_implemented?
      true
    end

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

      response.parsed_response if response&.parsed_response
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

      dispatcher_phone = dispatcher.phone.delete('^0-9')
      shipper_phone = shipment.origin.contact.phone.delete('^0-9')
      receiver_phone = shipment.destination.contact.phone.delete('^0-9')

      declared_value = if shipment.declared_value_cents.blank?
                         '0'
                       else
                         format('%.2f', (shipment.declared_value_cents.to_f / 100).ceil)
                       end

      palletized = !shipment.packages.map(&:packaging).map(&:pallet?).any?(false)
      service = palletized ? 'H' : 'C'

      base_api_shipment = {
        'consignee': {
          'Name': shipment.destination.contact.company_name,
          'Addr1': shipment.destination.address1,
          'Addr2': '',
          'Addr3': '',
          'City': shipment.destination.city,
          'Contact': shipment.destination.contact.name || 'Shipping',
          'Phone': shipment.destination.contact.phone || '',
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
        'LabelType': '0',
        'Reference': shipment.order_number,
        'Reference2': shipment.po_number,
        'Reference3': '',
        'Residential': shipment.accessorials.include?(:residential_delivery) ? 'true' : 'false',
        'SaturdayDel': 'false',
        'Service': palletized ? 'H' : 'C', # TODO: Double-check this
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
              'Weight': package.pounds(:each).ceil
            }
          )
        end
      end

      request = {
        headers: XML_HEADERS,
        method: @conf.dig(:api, :methods, :pickup),
        url: build_url(:pickup),
        body: {
          'Shipments': api_shipments
        }.to_xml(root: 'OnTracShipmentRequest')
      }

      save_request(request)
      request
    end

    def parse_pickup_response(response)
      response
    end

    # Rates

    def build_rate_request(shipment:)
      serviceable_accessorials?(shipment.accessorials)

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
          palletized = !shipment.packages.map(&:packaging).map(&:pallet?).any?(false)
          service = palletized ? 'H' : 'C'

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
          parts << service
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
      raise Interstellar::ResponseError, "API Error: #{response[:error]}" unless response[:error].blank?

      error = response.dig('OnTracRateResponse', 'Shipments', 'Shipment', 'Error')

      unless error.blank?
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
                  :standard
                when 'H'
                  :standard
                else
                  :standard
                end

      RateResponse.new(
        true,
        '',
        response,
        rates: [
          RateEstimate.new(
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
        response:,
        request: last_request
      )
    end

    # Tracking
  end
end
