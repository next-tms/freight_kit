# frozen_string_literal: true

module Interstellar
  class FWDA < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Forward Air'
    @@scac = 'FWDA'

    JSON_HEADERS = {
      'Accept': 'application/json',
      'charset': 'utf-8',
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
      options = @options.merge(options)
      "#{base_url}#{@conf.dig(:api, :endpoints, action)}"
    end

    def base_url
      env = @test_mode ? :test : :production
      "https://#{@conf.dig(:api, :domains, env)}"
    end

    def build_headers(options = {})
      options = @options.merge(options)
      if !options[:username].blank? && !options[:password].blank? && !options[:account].blank?
        return JSON_HEADERS.merge(
          'user': options[:username],
          'password': options[:password],
          'customerId': options[:username]&.upcase
        )
      end

      JSON_HEADERS
    end

    def build_request(action, options = {})
      options = @options.merge(options)
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
                   HTTParty.post(url, headers:, body:)
                 else
                   HTTParty.get(url, headers:)
                 end

      json = JSON.parse(response.body)
      error = json['errorMessage']

      return json if error.blank?

      raise Interstellar::InvalidCredentialsError, error if error.downcase.include?('not authorized')
      raise Interstellar::InvalidCredentialsError, error if error.downcase.include?('shipper client does not exist')

      raise Interstellar::ResponseError, error
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
      pickup_accessorials, delivery_accessorials = build_accessorials(shipment.accessorials)

      dispatcher_phone = dispatcher.phone.delete('^0-9')
      shipper_phone = shipment.origin.contact.phone.delete('^0-9')
      receiver_phone = shipment.destination.contact.phone.delete('^0-9')

      declared_value = if shipment.declared_value_cents.blank?
                         '0'
                       else
                         format('%.2f', (shipment.declared_value_cents.to_f / 100).ceil)
                       end

      request = {
        headers: build_headers(@options),
        method: @conf.dig(:api, :methods, :pickup),
        url: build_url(:pickup, @options),
        body: {
          testmode: test_mode? ? 'Y' : 'N',
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
            consigneeState: shipment.destination.state,
            consigneeZipCode: shipment.destination.zip.to_s
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
            shipperState: shipment.origin.state,
            shipperZipCode: shipment.origin.zip.to_s
          },
          orderDetails: {
            airbillNumber: '00000000',
            billToCustomerNumber: @options[:account]&.to_s || '',
            customerReferenceNumber: shipment.po_number,
            declaredValue: declared_value,
            description: shipment.packages.map(&:description).reject(&:blank?).uniq.join(', '),
            destinationAirportCode: '',
            guaranteedService: 'N',
            hazmat: shipment.packages.map(&:hazmat).include?(true) ? 'Y' : 'N',
            inBondShipment: declared_value.to_f.positive? ? 'Y' : 'N',
            orderAction: 'CREATE',
            originAirportCode: '',
            shippingDate: pickup_from.strftime('%Y-%m-%d'),
            shipperCustomerNumber: @options[:account]&.to_s || '',
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
              phone: dispatcher.phone
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
      response['airbillNumber']
    end

    # Rates

    def build_rate_request(shipment:)
      pickup_accessorials, delivery_accessorials = build_accessorials(shipment.accessorials)
      freight_details = build_freight_details(shipment.packages)

      declared_value = if shipment.declared_value_cents.blank?
                         '0'
                       else
                         format('%.2f', (shipment.declared_value_cents.to_f / 100).ceil)
                       end

      request = {
        url: build_url(:rates, @options),
        headers: build_headers(@options),
        method: @conf.dig(:api, :methods, :rates),
        body: {
          billToCustomerNumber: @options[:account],
          origin: {
            originZipCode: shipment.origin.zip.to_s.upcase,
            pickup: {
              airportPickup: pickup_accessorials&.include?('ALP') ? 'Y' : 'N',
              pickupAccessorials: { pickupAccessorial: pickup_accessorials }
            }
          },
          destination: {
            destinationZipCode: shipment.destination.zip.to_s.upcase,
            delivery: {
              airportDelivery: delivery_accessorials&.include?('ALD') ? 'Y' : 'N',
              deliveryAccessorials: { deliveryAccessorial: delivery_accessorials }
            }
          },
          freightDetails: { freightDetail: freight_details },
          hazmat: shipment.packages.map(&:hazmat).include?(true) ? 'Y' : 'N',
          inBondShipment: 'N',
          declaredValue: declared_value,
          shippingDate: Date.current.strftime('%Y-%m-%d')
        }.to_json
      }

      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:)
      success = true
      message = ''

      if !response
        success = false
        message = 'API Error: Unknown response'
      elsif response.key?('errorMessage')
        success = false
        message = response['errorMessage']
      else
        cost = response['quoteTotal']
        if cost
          cost = (cost.to_f * 100).to_i
          transit_days = response['transitDaysTotal']

          rate_estimates = [
            RateEstimate.new(
              shipment.origin,
              shipment.destination,
              self.class,
              :standard,
              transit_days:,
              estimate_reference: nil,
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

      RateResponse.new(
        success,
        message,
        response.to_hash,
        rates: rate_estimates,
        response:,
        request: last_request
      )
    end

    # Tracking
  end
end
