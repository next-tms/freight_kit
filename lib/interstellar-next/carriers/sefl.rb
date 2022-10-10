# frozen_string_literal: true

module Interstellar
  class SEFL < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Southeastern Freight Lines'
    @@scac = 'SEFL'

    JSON_HEADERS = {
      Accept: 'application/json',
      charset: 'utf-8',
      'Content-Type' => 'application/x-www-form-urlencoded'
    }.freeze

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

    def required_credential_types
      %i[api]
    end

    # Documents

    # Rates
    def find_rates(shipment:)
      begin
        validate_packages(shipment.packages)
      rescue UnserviceableError => e
        return RateResponse.new(error: e)
      end

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

    def build_url(action)
      "#{base_url}#{@conf.dig(:api, :endpoints, action)}"
    end

    def base_url
      "https://#{@conf.dig(:api, :domain)}"
    end

    def auth_header
      api_credentials = fetch_credential(:api)
      auth = Base64.strict_encode64("#{api_credentials.username}:#{api_credentials.password}")

      { Authorization: "Basic #{auth}" }
    end

    def build_request(action, options = {})
      headers = JSON_HEADERS
      headers = headers.merge(auth_header)
      headers = headers.merge(options[:headers]) unless options[:headers].blank?
      body = URI.encode_www_form(options[:body]) unless options[:body].blank?

      request = {
        url: options[:url].blank? ? build_url(action) : options[:url],
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

      case method
      when :post
        HTTParty.post(url, headers:, body:)
      else
        HTTParty.get(url, headers:)
      end
    end

    # Documents

    # Rates
    def build_rate_request(shipment:)
      accessorials = []
      unless shipment.accessorials.blank?
        serviceable_accessorials?(shipment.accessorials)
        shipment.accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << @conf.dig(:accessorials, :mappable)[a]
          end
        end
      end

      longest_dimension = shipment.packages.map { |p| [p.width(:inches), p.length(:inches)].max }.max.ceil
      accessorials << 'chkOD' if longest_dimension >= 96

      accessorials = accessorials.uniq
      pickup_on = Date.current
      shipment_description = shipment.packages.map(&:description).reject(&:blank?).uniq.join(', ')
      shipment_description = 'Freight All Kinds' if shipment_description.blank?

      api_credentials = fetch_credential(:api)

      body = {
        allowSpot: longest_dimension >= 120 ? 'Y' : 'N',
        CustomerAccount: api_credentials.account.to_i.to_s.rjust(9, '0'),
        CustomerCity: customer_location.city,
        CustomerName: customer_location.contact.company_name,
        CustomerState: customer_location.province,
        CustomerStreet: customer_location.address1,
        CustomerZip: customer_location.postal_code,
        Description: shipment_description,
        DestCountry: 'U',
        DestinationCity: shipment.destination.city,
        DestinationState: shipment.destination.province,
        DestinationZip: shipment.destination.postal_code,
        DimsOption: 'I',
        EmailAddress: customer_location.contact.email,
        Option: 'T',
        OrigCountry: 'U',
        OriginCity: shipment.origin.city,
        OriginState: shipment.origin.province,
        OriginZip: shipment.origin.postal_code,
        PickupDay: pickup_on.strftime('%_d'),
        PickupMonth: pickup_on.strftime('%_m'),
        PickupYear: pickup_on.strftime('%Y'),
        rateXML: 'Y',
        returnX: 'Y',
        Terms: 'P'
      }

      declared_value = if shipment.declared_value_cents.blank?
                         '0'
                       else
                         format('%.2f', (shipment.declared_value_cents.to_f / 100).ceil)
                       end

      unless declared_value.blank?
        body = body.deep_merge(
          {
            chkIN: 'on',
            FVInsuranceAmount: declared_value
          }
        )
      end

      if longest_dimension >= 96
        body = body.deep_merge(
          {
            ODLength: longest_dimension,
            ODLengthUnit: 'I'
          }
        )
      end

      cubic_ft_required = shipment.destination.province.upcase == 'PR'

      i = 0
      shipment.packages.each do |package|
        package.quantity.times do
          i += 1

          body = body.deep_merge({ "Class#{i}": package.freight_class.to_s.sub('.', '').to_i })
          body = body.deep_merge({ "Description#{i}": package.description || 'Freight' })
          body = body.deep_merge({ "PieceLength#{i}": package.length(:in).ceil })
          body = body.deep_merge({ "PieceWidth#{i}": package.width(:in).ceil })
          body = body.deep_merge({ "PieceHeight#{i}": package.height(:in).ceil })
          body = body.deep_merge({ "Weight#{i}": package.pounds(:each).ceil })

          body = body.deep_merge({ "CubicFt#{i}": package.cubic_ft(:each) }) if cubic_ft_required
        end
      end

      body = body.deep_merge({ accessorial: 'on' }) unless accessorials.blank?

      request = build_request(:rates, body:)
      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:, tries: 0)
      rate_response = RateResponse.new(request: last_request, response:)

      # Used begin rescue block's retry instead.
      # if tries > 10
      #   rate_response.error = ResponseError.new("Timeout after #{tries * 5} seconds")
      #   return rate_response
      # end

      if response.body.blank?
        rate_response.error = InvalidCredentialsError if response.code == 401

        rate_response.error = ResponseError.new('Unknown response') if rate_response.error.blank?
        return rate_response
      end

      begin
        response = JSON.parse(response.body)
      rescue JSON::ParserError
        sleep(5)
        if tries > 10
          rate_response.error = ResponseError.new("Timeout after #{tries * 5} seconds")
          return rate_response
        end

        tries += 1
        retry
      end

      error = response['errorMessage']

      unless error.blank?
        if error.include?('one point must be directly serviced')
          rate_response.error = UnserviceableError.new(error.sub(' by SEFL.', ''))
        end

        rate_response.error = ResponseError.new(error) if rate_response.error.blank?
        return rate_response
      end

      url = response['detailQuoteLocation'].gsub('\\', '')
      request = build_request(:get_rate, url:)

      tries = 0

      until tries > 10
        save_request(request)
        response = commit(request)

        if response.body.blank?
          rate_response.error = InvalidCredentialsError if response.code == 401

          rate_response.error = ResponseError.new('Unknown response') if rate_response.error.blank?
          return rate_response
        end

        response = JSON.parse(response.body)

        if response.blank?
          rate_response.error = ResponseError.new('Unknown response')
          return rate_response
        end

        error = response['errorMessage']

        unless error.blank?
          if error.downcase.include?('not yet been processed')
            sleep(5)
            tries += 1
            next
          else
            rate_response.error = ResponseError.new(error)
            return rate_response
          end
        end

        tries = 50
      end

      if response['rateQuote'].blank?
        rate_response.error = ResponseError.new('Cost is empty')
        return rate_response
      end

      estimate_reference = response['quoteNumber']
      transit_days = response['transitTime'].to_i

      details = response['details']
      prices = []

      # return details

      details.each do |detail|
        next if detail['typeCharge'].include?('TTL') || detail['typeCharge'].include?('NFC')

        cents = detail['charges'].squish
        cents = cents.blank? ? 0 : (cents.to_f * 100).to_i
        next if cents.zero?

        description = detail['description'].squish

        cents *= -1 if detail['description'].include?('DISCOUNT')

        prices << Price.new(blame: :api, cents:, description:)
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
  end
end
