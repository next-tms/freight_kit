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
        raise ArgumentError, "#{self.class.name}: Some accessorials unserviceable"
      end

      true
    end

    # Documents

    # Rates
    def find_rates(origin, destination, packages, options = {})
      options = @options.merge(options)
      origin = Location.from(origin)
      destination = Location.from(destination)
      packages = Array(packages)

      request = build_rate_request(origin, destination, packages, options)
      parse_rate_response(origin, destination, commit(request))
    end

    # Tracking

    protected

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
                   HTTParty.post(url, headers: headers, body: body)
                 else
                   HTTParty.get(url, headers: headers)
                 end

      JSON.parse(response.body)
    end

    # Documents

    # Rates
    def build_rate_request(origin, destination, packages, options = {})
      options = @options.merge(options)

      delivery_accessorials = []
      pickup_accessorials = []
      unless options[:accessorials].blank?
        serviceable_accessorials?(options[:accessorials])
        options[:accessorials].each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            if @conf.dig(:accessorials, :mappable, :pickup).include?(a)
              pickup_accessorials << @conf.dig(:accessorials, :mappable, :pickup)[a]
            elsif delivery_accessorials << @conf.dig(:accessorials, :mappable, :delivery)[a]
            end
          end
        end
      end

      unless delivery_accessorials.blank?
        # Remove duplicate delivery appointment accessorial when residential delivery (included with RDE)
        delivery_accessorials -= ['ADE'] if delivery_accessorials.include?('RDE')
      end

      unless pickup_accessorials.blank?
        # Remove duplicate pickup appointment accessorial when residential pickup (included with RPU)
        pickup_accessorials -= ['APP'] if pickup_accessorials.include?('RPU')
      end

      delivery_accessorials = delivery_accessorials.uniq
      pickup_accessorials = pickup_accessorials.uniq

      # API doesn't like empty arrays
      delivery_accessorials = nil if delivery_accessorials.blank?
      pickup_accessorials = nil if pickup_accessorials.blank?

      freight_details = []
      packages.each do |package|
        freight_details << {
          description: 'Freight',
          freightClass: package.freight_class.to_s,
          pieces: '1',
          weightType: 'L',
          weight: package.pounds.ceil.to_s
        }
      end

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
          hazmat: 'N',
          inBondShipment: 'N',
          declaredValue: '0.00',
          shipmentDate: Date.current.strftime('%Y-%m-%d')
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
