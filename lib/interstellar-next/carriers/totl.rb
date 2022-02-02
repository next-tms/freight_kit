# frozen_string_literal: true

module Interstellar
  class TOTL < CarrierLogistics
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Total Transportation'
    @@scac = 'TOTL'

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(10_000, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(40, :inches)
    end

    def overlength_fees_require_tariff?
      false
    end

    def requirements
      %i[username password account]
    end

    # Documents

    def bol_requires_tracking_number?
      true
    end

    # Pickups

    def pickup_number_is_tracking_number?
      true
    end

    # Rates

    def build_calculated_accessorials(*); end

    # Tracking

    # protected

    # Documents

    # Rates

    def parse_rate_response(shipment:, response:)
      raise Interstellar::ResponseError, 'API Error: Unknown response' if response.blank?

      if response.is_a?(String) && response.include?('WebSpeed error')
        raise Interstellar::ResponseError, 'API Error: Temporary error (CarrierLogistics WebSpeed error)'
      end

      error = response.dig('error', 'errormessage')

      unless error.blank?
        raise Interstellar::InvalidCredentialsError if error.downcase.include?('invalid username/password')
        raise Interstellar::UnserviceableError, error if error.downcase.include?('is not available')
        raise Interstellar::UnserviceableError, error if error.downcase.include?('out of the serviceable area')

        raise ResponseError, "API Error: #{error}"
      end

      raise ResponseError, 'Cost is blank' if response.dig('ratequote', 'quotetotal').blank?

      total_cents = parse_amount(response.dig('ratequote', 'quotetotal'))

      transit_days = response.dig('ratequote', 'busdays').to_i
      estimate_reference = response.dig('ratequote', 'quotenumber')

      ratequote_lines = response.dig('ratequote', 'ratequoteline')
      prices = []

      ratequote_lines.each do |ratequote_line|
        next if ratequote_line['chrg'].blank?
        next if ratequote_line['chargedesc'] == 'FREIGHT'

        cents = parse_amount(ratequote_line['chrg'])
        next if cents.zero?

        prices << Price.new(
          blame: :api,
          cents:,
          description: ratequote_line_description(ratequote_line)
        )
      end

      prices = [
        Price.new(
          blame: :api,
          cents: total_cents - prices.sum(&:cents),
          description: 'Freight'
        )
      ] + prices

      # Carrier-specific pricing structure
      oversized_pallets_cents = 0

      shipment.packages.each do |package|
        short_side, long_side = nil
        if !package.length(:in).blank? && !package.width(:in).blank? && !package.height(:in).blank?
          long_side = package.length(:in) > package.width(:in) ? package.length(:in) : package.width(:in)
          short_side = package.length(:in) < package.width(:in) ? package.length(:in) : package.width(:in)
        end

        next unless short_side &&
                    long_side &&
                    package.height(:in) &&
                    (
                      short_side > 40 ||
                      long_side > 48 ||
                      package.height(:in) > 84
                    )

        oversized_pallets_cents += 1500
      end

      unless oversized_pallets_cents.zero?
        prices << Price.new(
          blame: :library,
          cents: oversized_pallets_cents,
          description: 'Overlength fees'
        )
      end

      RateResponse.new(
        true,
        'OK',
        response.to_hash,
        rates: [
          RateEstimate.new(
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
        ],
        response:,
        request: last_request
      )
    end
  end
end
