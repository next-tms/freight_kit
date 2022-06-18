# frozen_string_literal: true

module Interstellar
  class CNWY < Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'XPO Logistics'
    @@scac = 'CNWY'

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

    # Pickups

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

    # Tracking

    protected

    def build_headers
      {
        accept: 'application/json',
        authorization: "Bearer #{bearer_token}",
        'Content-Type': 'application/json'
      }
    end

    def bearer_token
      @bearer_token ||= commit(build_bearer_token_request)[:access_token]
    end

    def build_bearer_token_request
      api_credentials = fetch_credential(:api)

      body = URI.encode_www_form(
        grant_type: 'password',
        password: api_credentials.password,
        username: api_credentials.username
      )

      {
        body:,
        headers: {
          authorization: "Basic #{api_credentials.api_key}",
          content_type: 'application/x-www-form-urlencoded'
        },
        method: :post,
        url: build_url(:token)
      }
    end

    def build_url(action)
      scheme = @conf.dig(:api, :use_ssl) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
    end

    def commit(request)
      url = request[:url]
      headers = request[:headers] || build_headers
      method = request[:method]
      body = request[:body]

      response = case method
                 when :post
                   HTTParty.post(url, headers:, body:, debug_output: $stdout)
                 else
                   HTTParty.get(url, headers:, debug_output: $stdout)
                 end

      json = JSON.parse(response.body).deep_symbolize_keys

      error = if json.is_a?(Hash)
                json[:error_description] || json.dig(:fault, :description) || json.dig(:error, :message)
              end

      if error.blank?
        return json if response.code == 200
      else
        case response.code
        when 401
          raise Interstellar::InvalidCredentialsError
        end
      end

      raise Interstellar::ResponseError, error
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domains, action)}#{@conf.dig(:api, :endpoints, action)}"
    end

    # Documents

    # Rates

    def build_accessorials(shipment:)
      serviceable_accessorials?(shipment.accessorials)

      accessorial_codes = []
      accessorial_codes << 'SSC'
      accessorial_codes << 'ZHM' if shipment.hazmat?

      if shipment.destination.province.upcase == 'HI'
        accessorial_codes = accessorial_codes.map { |code| %w[DID OIP].include?(code) ? 'WHN' : code }.uniq
      end

      longest_dimension_in = shipment.packages.map { |p| [p.width(:inch), p.length(:inch)].max }.max.ceil

      # Switch to accessorials rather than accessorial_codes since now we need more complex structures

      accessorials = accessorial_codes.map { |accessorial_code| { accessorial_cd: accessorial_code, quantity: 0 } }

      return accessorials if longest_dimension_in < 96 && shipment.accessorials.blank?

      if longest_dimension_in >= 96
        accessorials << {
          accessorial_cd: 'ELS',
          quantity_uom: 'INCH',
          quantity: longest_dimension_in
        }
      end

      return accessorials if shipment.accessorials.blank?

      shipment.accessorials.map do |accessorial|
        next if @conf.dig(:accessorials, :unquotable).include?(accessorial)

        accessorials << { accessorial_cd: @conf.dig(:accessorials, :mappable, accessorial), quantity: 0 }
      end

      accessorials
    end

    def parse_amount(amount)
      (amount.to_f * 100).to_i
    end

    def build_commodity(shipment:)
      shipment.packages.map do |package|
        {
          dimensions: {
            dimensions_uom: 'INCH',
            height: package.inches(:height).ceil,
            length: package.inches(:length).ceil,
            width: package.inches(:width).ceil
          },
          gross_weight: {
            weight: package.pounds(:total).ceil,
            weight_uom: 'LBS'
          },
          hazmat_ind: package.hazmat?,
          nmfc_class: package.freight_class.to_s,
          nmfc_item_cd: package.nmfc,
          piece_cnt: package.quantity
        }
      end
    end

    def build_rate_request(shipment:)
      api_credentials = fetch_credential(:api)
      shipment_date = (::DateTime.now + 3.days).iso8601 # TODO: Fix

      accessorials = build_accessorials(shipment:)
      commodity = build_commodity(shipment:)

      body = {
        shipmentInfo: {
          accessorials:,
          bill_2_party: { acct_inst_id: api_credentials.account },
          commodity:,
          consignee: { address: { postal_cd: shipment.destination.postal_code.to_s } },
          pallet_cnt: shipment.packages.map(&:packaging).map(&:pallet?).count(true),
          payment_term_cd: 'P', # prepaid,
          shipment_date:,
          shipper: { address: { postal_cd: shipment.origin.postal_code.to_s } }
        }
      }.deep_transform_keys! { |key| key.to_s.camelize(:lower) }.to_json

      request = {
        body:,
        headers: build_headers,
        method: :post,
        url: build_url(:rates)
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

      if response.dig(:data, :rateQuote, :totCharge, 0, :amt).blank?
        rate_response.error = ResponseError.new('Cost is empty')
        return rate_response
      end

      accessorials = response.dig(:data, :rateQuote, :shipmentInfo, :accessorials)
      commodities = response.dig(:data, :rateQuote, :shipmentInfo, :commodity)
      deficit_weight = response.dig(:data, :rateQuote, :deficitRatingInfo)

      prices = []

      prices << Interstellar::Price.new(
        blame: :api,
        cents: parse_amount(
          commodities.sum { |c| c.dig(:charge, :chargeAmt, :amt) }
        ),
        description: 'Freight'
      )

      prices << Interstellar::Price.new(
        blame: :api,
        cents: parse_amount(deficit_weight.dig(:deficitAmt, :amt)),
        description: <<~DESC.squish
          Deficit weight
          #{deficit_weight.dig(:deficitWght, :weight).ceil}
          #{deficit_weight.dig(:deficitWght, :weightUom).downcase}
        DESC
      )

      prices << Interstellar::Price.new(
        blame: :api,
        cents: parse_amount(response.dig(:data, :rateQuote, :totDiscountAmt, :amt)) * -1,
        description: "Discount #{response.dig(:data, :rateQuote, :actlDiscountPct)}%"
      )

      prices += accessorials.map do |accessorial|
        Interstellar::Price.new(
          blame: :api,
          cents: parse_amount(accessorial.dig(:chargeAmt, :amt)),
          description: accessorial[:accessorialDesc].squish.capitalize.gsub('Xpo', 'XPO')
        )
      end

      comment = response.dig(:data, :rateQuote, :shipmentInfo, :comment)
      days = if comment.blank?
               nil
             else
               comment.match(/\d+ days/)&.to_s&.split(' days')&.first&.to_i
             end

      expires_at = if days.is_a?(Integer) && days.positive?
                     days.days.from_now
                   else
                     2.days.from_now
                   end

      estimate_reference = response.dig(:data, :rateQuote, :confirmationNbr)
      transit_days = response.dig(:data, :transitTime, :transitDays)

      rate = Rate.new(
        carrier: self,
        carrier_name: self.class.name,
        currency: 'USD',
        estimate_reference:,
        expires_at:,
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
