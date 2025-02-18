# frozen_string_literal: true

module FreightKit
  class TOTL < CarrierLogistics
    class << self
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

      def pickup_number_is_tracking_number?
        true
      end

      def required_credential_types
        %i[api]
      end

      def requirements
        %i[credentials]
      end
    end

    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Total Transportation'
    @@scac = 'TOTL'

    # Documents

    # Pickups

    # Rates

    # Tracking

    # protected

    # Documents

    # Rates

    def parse_rate_response(shipment:, response:)
      rate_response = RateResponse.new(request: last_request, response:)

      if response.blank?
        rate_response.error = ResponseError.new('Unknown response')
        return rate_response
      end

      if response.is_a?(String) && response.include?('WebSpeed error')
        rate_response.error = ResponseError.new('API Error: Temporary error (CarrierLogistics WebSpeed error)')
        return rate_response
      end

      error = response.dig('error', 'errormessage')

      if error.present?
        if error.downcase.include?('invalid username/password')
          rate_response.error = InvalidCredentialsError.new
          return rate_response
        end

        if error.downcase.include?('is not available') || error.downcase.include?('out of the serviceable area')
          rate_response.error = UnserviceableError.new
          return rate_response
        end

        rate_response.error = ResponseError.new("API Error: #{error}")
        return rate_response
      end

      if response.dig('ratequote', 'quotetotal').blank?
        rate_response.error = ResponseError.new('Cost is blank')
        return rate_response
      end

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
          description: ratequote_line_description(ratequote_line),
        )
      end

      prices = [
                 Price.new(
                   blame: :api,
                   cents: total_cents - prices.sum(&:cents),
                   description: 'Freight',
                 ),
               ] + prices

      # Carrier-specific pricing structure
      oversized_pallets_cents = 0

      shipment.packages.each do |package|
        short_side, long_side = nil
        if package.length(:in).present? && package.width(:in).present? && package.height(:in).present?
          long_side = [package.length(:in), package.width(:in)].max
          short_side = [package.length(:in), package.width(:in)].min
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

      if oversized_pallets_cents.nonzero?
        prices << Price.new(
          blame: :library,
          cents: oversized_pallets_cents,
          description: 'Overlength fees',
        )
      end

      RateResponse.new(
        rates: [
                 Rate.new(
                   carrier: self,
                   carrier_name: self.class.name,
                   currency: 'USD',
                   estimate_reference:,
                   scac: self.class.scac.upcase,
                   service_name: :standard,
                   shipment:,
                   prices:,
                   transit_days:,
                   with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees),
                 ),
               ],
        request: last_request,
        response:,
      )
    end
  end
end
