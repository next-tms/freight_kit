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
      accessorials:,
      customer_reference:,
      delivery_from:,
      delivery_to:,
      destination:,
      origin:,
      packages:,
      pickup_from:,
      pickup_to:,
      receiver_contact_name:,
      receiver_name:,
      receiver_phone:,
      scac:,
      service:,
      shipper_contact_name:,
      shipper_name:,
      shipper_phone:,
      shipper_reference:
    )
      request = build_pickup_request(
        accessorials: accessorials,
        customer_reference: customer_reference,
        delivery_from: delivery_from,
        delivery_to: delivery_to,
        destination: destination,
        origin: origin,
        packages: packages,
        pickup_from: pickup_from,
        pickup_to: pickup_to,
        receiver_contact_name: receiver_contact_name,
        receiver_name: receiver_name,
        receiver_phone: receiver_phone,
        scac: scac,
        service: service,
        shipper_contact_name: shipper_contact_name,
        shipper_name: shipper_name,
        shipper_phone: shipper_phone,
        shipper_reference: shipper_reference
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

    def find_rates(origin, destination, packages, options = {})
      options = @options.merge(options)
      origin = Location.from(origin)
      destination = Location.from(destination)
      packages = Array(packages)

      request = build_rate_request(origin, destination, packages, options)
      parse_rate_response(origin, destination, commit(request))
    end

    def find_rates_implemented?
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
          pieces: package.quantity,
          weightType: 'L',
          weight: package.pounds(:total).ceil
        }
      end
    end

    def build_url(action, options = {})
      options = @options.merge(options)
      "#{base_url}#{@conf.dig(:api, :endpoints, action)}"
    end

    def base_url
      "https://#{@conf.dig(:api, :domain)}"
    end

    def build_headers(options = {})
      options = @options.merge(options)
      if !options[:username].blank? && !options[:password].blank? && !options[:account].blank?
        return JSON_HEADERS.merge(
          'user': options[:username],
          'password': options[:password],
          'customerId': options[:account]
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
        headers: headers,
        method: @conf.dig(:api, :methods, action),
        body: body
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
                   HTTParty.post(url, headers: headers, body: body, debug_output: $stdout)
                 else
                   HTTParty.get(url, headers: headers)
                 end

      JSON.parse(response.body)
    end

    # Documents

    # Pickups

    def build_pickup_request(
      accessorials:,
      customer_reference:,
      delivery_from:,
      delivery_to:,
      destination:,
      origin:,
      packages:,
      pickup_from:,
      pickup_to:,
      receiver_contact_name:,
      receiver_name:,
      receiver_phone:,
      scac:,
      service:,
      shipper_contact_name:,
      shipper_name:,
      shipper_phone:,
      shipper_reference:
    )
      options = @options
      pickup_accessorials, delivery_accessorials = build_accessorials(accessorials)

      shipper_phone = shipper_phone.gsub(/\s+/, '').gsub(/[()-+.]/, '')
      shipper_phone = shipper_phone[1..] if shipper_phone.length == 11

      receiver_phone = receiver_phone.gsub(/\s+/, '').gsub(/[()-+.]/, '')
      receiver_phone = receiver_phone[1..] if receiver_phone.length == 11

      request = {
        headers: build_headers(options),
        method: @conf.dig(:api, :methods, :pickup),
        testmode: @options[:test] ? 'Y' : 'N',
        url: build_url(:pickup, options),
        body: {
          orderAction: 'Create',
          billToCustomerNumber: options[:account],
          shipperCustomerNumber: options[:account],
          order: {
            declaredValue: 0,
            freightDetails: { freightDetail: build_freight_details(packages) },
            hazmat: packages.map(&:hazmat).include?(true) ? 'Y' : 'N',
            inBondShipment: 'N',
            shippingDate: pickup_from.strftime('%Y-%m-%d'),
            special_instructions: '',
            consignee: {
              consigneeAddress1: destination.to_hash[:address1],
              consigneeCity: destination.to_hash[:city],
              consigneeCloseTime: delivery_to.strftime('%H:%M:00'),
              consigneeContactEmail: '',
              consigneeContactName: receiver_contact_name || 'Receiving',
              consigneeContactPhone: receiver_phone || '',
              consigneeCountry: destination.country.code(:alpha2).to_s,
              consigneeLocationName: receiver_name,
              consigneeOpenTime: delivery_from.strftime('%H:%M:00'),
              consigneeState: destination.to_hash[:province],
              consigneeZipCode: destination.to_hash[:postal_code].to_s
            },
            delivery: {
              destinationZipCode: destination.to_hash[:postal_code].to_s.upcase,
              delivery: {
                airportDelivery: delivery_accessorials&.include?('ALD') ? 'Y' : 'N',
                deliveryAccessorials: { deliveryAccessorial: delivery_accessorials }
              }
            },
            dimensions: packages.map do |package|
              {
                height: package.inches(:height).ceil,
                length: package.inches(:length).ceil,
                width: package.inches(:width).ceil,
                pieces: package.quantity
              }
            end,
            emergencyContact: {
              email: '',
              name: '',
              phone: ''
            },
            pickup: {
              originZipCode: origin.to_hash[:postal_code].to_s.upcase,
              pickup: {
                airportPickup: pickup_accessorials&.include?('ALP') ? 'Y' : 'N',
                pickupAccessorials: { pickupAccessorial: pickup_accessorials },
                pickupReadyTime: pickup_from.strftime('%H:%M:00')
              }
            },
            shipper: {
              shipperAddress1: origin.to_hash[:address1],
              shipperCity: origin.to_hash[:city],
              shipperCloseTime: pickup_to.strftime('%H:%M:00'),
              shipperContactEmail: '',
              shipperContactName: shipper_contact_name || 'Shipping',
              shipperContactPhone: shipper_phone || '',
              shipperCountry: origin.country.code(:alpha2).to_s,
              shipperLocationName: shipper_name,
              shipperOpenTime: pickup_from.strftime('%H:%M:00'),
              shipperState: origin.to_hash[:province],
              shipperZipCode: origin.to_hash[:postal_code].to_s
            }
          }
        }.to_json
      }

      save_request(request)
      request
    end

    def parse_pickup_response(response)
      pp response
      response&.dig('AirbillNumber')
    end

    # Rates

    def build_rate_request(origin, destination, packages, options = {})
      options = @options.merge(options)

      pickup_accessorials, delivery_accessorials = build_accessorials(options[:accessorials])
      freight_details = build_freight_details(packages)

      request = {
        url: build_url(:rates, options),
        headers: build_headers(options),
        method: @conf.dig(:api, :methods, :rates),
        body: {
          billToCustomerNumber: options[:account],
          origin: {
            originZipCode: origin.to_hash[:postal_code].to_s.upcase,
            pickup: {
              airportPickup: pickup_accessorials&.include?('ALP') ? 'Y' : 'N',
              pickupAccessorials: { pickupAccessorial: pickup_accessorials }
            }
          },
          destination: {
            destinationZipCode: destination.to_hash[:postal_code].to_s.upcase,
            delivery: {
              airportDelivery: delivery_accessorials&.include?('ALD') ? 'Y' : 'N',
              deliveryAccessorials: { deliveryAccessorial: delivery_accessorials }
            }
          },
          freightDetails: { freightDetail: freight_details },
          hazmat: packages.map(&:hazmat).include?(true) ? 'Y' : 'N',
          inBondShipment: 'N',
          declaredValue: 0,
          shippingDate: Date.current.strftime('%Y-%m-%d')
        }.to_json
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
      elsif response.key?('errorMessage')
        success = false
        message = response.dig('errorMessage')
      else
        cost = response.dig('quoteTotal')
        if cost
          cost = (cost.to_f * 100).to_i
          transit_days = response.dig('transitDaysTotal')

          rate_estimates = [
            RateEstimate.new(
              origin,
              destination,
              self.class,
              :standard,
              transit_days: transit_days,
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
        response: response,
        request: last_request
      )
    end

    # Tracking
  end
end
