# frozen_string_literal: true

module HyperCarrier
  class TOTL < CarrierLogistics
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Total Transportation'
    @@scac = 'TOTL'

    def requirements
      %i[username password account]
    end

    # Documents

    # Rates
    def build_calculated_accessorials(*); end

    # Tracking

    # protected

    # Documents

    # Rates

    def parse_rate_response(origin, destination, packages, response)
      success = true
      message = ''

      if !response
        success = false
        message = 'API Error: Unknown response'
      else
        if response['error']
          success = false
          message = response['error']
        else
          cost = response.dig('ratequote', 'quotetotal').delete(',').delete('.').to_i
          transit_days = response.dig('ratequote', 'busdays').to_i
          if cost
            # Carrier-specific pricing structure
            oversized_pallets_price = 0
            packages.each do |package|
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

              oversized_pallets_price += 1500
            end
            cost += oversized_pallets_price

            rate_estimates = [
              RateEstimate.new(
                origin,
                destination,
                { scac: self.class.scac.upcase, name: self.class.name },
                :standard,
                transit_days: transit_days,
                estimate_reference: nil,
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
  end
end
