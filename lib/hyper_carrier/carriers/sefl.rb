# frozen_string_literal: true

module HyperCarrier
  class SEFL < HyperCarrier::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Southeastern Freight Lines'
    @@scac = 'SEFL'

    JSON_HEADERS = {
      'Accept': 'application/json',
      'charset': 'utf-8',
      'Content-Type' => 'application/x-www-form-urlencoded'
    }.freeze

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

    def auth_header(options = {})
      options = @options.merge(options)
      if !options[:username].blank? && !options[:password].blank?
        auth = Base64.strict_encode64("#{options[:username]}:#{options[:password]}")
        return { 'Authorization': "Basic #{auth}" }
      end

      {}
    end

    def build_request(action, options = {})
      options = @options.merge(options)
      headers = JSON_HEADERS
      headers = headers.merge(auth_header)
      headers = headers.merge(options[:headers]) unless options[:headers].blank?
      body = URI.encode_www_form(options[:body]) unless options[:body].blank?

      request = {
        url: options[:url].blank? ? build_url(action, options) : options[:url],
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

      response
    end

    # Documents

    # Rates
    def build_rate_request(origin, destination, packages, options = {})
      options = @options.merge(options)

      accessorials = []
      unless options[:accessorials].blank?
        serviceable_accessorials?(options[:accessorials])
        options[:accessorials].each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << @conf.dig(:accessorials, :mappable)[a]
          end
        end
      end

      longest_dimension = packages.inject([]) { |_arr, p| [p.length(:in), p.width(:in)] }.max.ceil
      accessorials << 'chkOD' if longest_dimension >= 96

      accessorials = accessorials.uniq

      pickup_on = options[:pickup_on].blank? ? Date.current : options[:pickup_on]

      body = {
        returnX: 'Y',
        rateXML: 'Y',
        CustomerAccount: options[:account].to_i.to_s.rjust(9, '0'),
        CustomerName: options[:customer_name],
        CustomerStreet: options.dig(:customer_address, :street),
        CustomerCity: options.dig(:customer_address, :city),
        CustomerState: options.dig(:customer_address, :state),
        CustomerZip: options.dig(:customer_address, :zip_code),
        Description: 'Freight All Kinds',
        Option: 'T',
        Terms: 'P',
        allowSpot: packages.inject(0) { |_sum, p| _sum += [p.length(:in), p.width(:in)].max.ceil } >= 120 ? 'Y' : 'N',
        DimsOption: 'I',
        EmailAddress: options[:customer_email].blank? ? 'unknown@fake.fake' : options[:customer_email],
        PickupMonth: pickup_on.strftime('%_m'),
        PickupDay: pickup_on.strftime('%_d'),
        PickupYear: pickup_on.strftime('%Y'),
        OriginCity: origin.to_hash[:city],
        OriginState: origin.to_hash[:province],
        OriginZip: origin.to_hash[:postal_code],
        OrigCountry: 'U',
        DestinationCity: destination.to_hash[:city],
        DestinationState: destination.to_hash[:province],
        DestinationZip: destination.to_hash[:postal_code],
        DestCountry: 'U'
      }

      if longest_dimension >= 96
        body = body.deep_merge(
          {
            ODLength: longest_dimension,
            ODLengthUnit: 'I'
          }
        )
      end

      i = 0
      packages.each do |package|
        i += 1
        body = body.deep_merge({ "Class#{i}": package.freight_class.to_s.sub('.', '').to_i })
        body = body.deep_merge({ "CubicFt#{i}": package.cubic_ft }) if destination.to_hash[:province].upcase == 'PR'
        body = body.deep_merge({ "Description#{i}": 'Freight All Kinds' })
        body = body.deep_merge({ "PieceLength#{i}": package.length(:in).ceil })
        body = body.deep_merge({ "PieceWidth#{i}": package.width(:in).ceil })
        body = body.deep_merge({ "PieceHeight#{i}": package.height(:in).ceil })
        body = body.deep_merge({ "Weight#{i}": package.pounds.ceil })
      end

      unless accessorials.blank?
        accessorials.each do |_accessorial|
          body = body.deep_merge({ accessorial: 'on' })
        end
      end

      request = build_request(:rates, body: body)

      save_request(request)
      request
    end

    def parse_rate_response(origin, destination, response)
      success = true
      message = ''

      if response.body.blank?
        if response.code == 401
          raise HyperCarrier::InvalidCredentialsError
        else
          success = false
          message = 'API Error: Unknown response'
        end
      else
        response = JSON.parse(response.body)
        sleep(5) # TODO: Maybe improve this?
        url = response.dig('detailQuoteLocation').gsub('\\', '')
        request = build_request(:get_rate, url: url)
        save_request(request)
        response = commit(request)

        if response.body.blank?
          if response.code == 401
            raise HyperCarrier::InvalidCredentialsError
          else
            success = false
            message = 'API Error: Unknown response'
          end
        else
          response = JSON.parse(response.body)
          if response.dig('errorMessage').blank?
            cost = response.dig('rateQuote')
            if cost
              cost = cost.sub('.', '').to_i
              estimate_reference = response.dig('quoteNumber')
              transit_days = response.dig('transitTime').to_i
  
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
          else
            success = false
            message = response.dig('errorMessage')
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
  end
end
