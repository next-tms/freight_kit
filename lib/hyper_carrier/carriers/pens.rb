# frozen_string_literal: true

module HyperCarrier
  class PENS < HyperCarrier::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Peninsula Truck Lines'
    @@scac = 'PENS'

    def requirements
      %i[username password account]
    end

    # Documents

    # Rates
    def find_rates(origin, destination, packages, options = {})
      options = @options.merge(options)
      origin = Location.from(origin)
      destination = Location.from(destination)
      packages = Array(packages)

      request = build_rate_request(origin, destination, packages, options)
      parse_rate_response(origin, destination, commit_soap(:rates, request))
    end

    # Tracking

    protected

    def commit_soap(action, request)
      Savon.client(
        wsdl: request_url(action),
        convert_request_keys_to: :lower_camelcase,
        env_namespace: :soap,
        element_form_default: :qualified
      ).call(
        @conf.dig(:api, :actions, action),
        message: request
      ).body.to_json
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domains, action)}#{@conf.dig(:api, :endpoints, action)}"
    end

    # Documents

    # Rates
    def build_rate_request(origin, destination, packages, options = {})
      options = @options.merge(options)

      request = {
        user_id: @options[:username],
        password: @options[:password],
        account: @options[:account],
        customer_type: @options[:customer_type].blank? ? 'B' : @options[:customer_type],
        origin_zip: origin.to_hash[:postal_code].to_s,
        destination_zip: destination.to_hash[:postal_code].to_s,
        accessorial_list: '', # TODO: Fix this!
        class_list: packages.map(&:freight_class).join(','),
        weight_list: packages.map(&:lbs).inject([]) { |weights, lbs| weights << lbs.ceil }.join(','),
        none_palletized_mode: 'N',
        plt_count_list: Array.new(packages.size, 1).join(','),
        plt_length_list: packages.map(&:inches).inject([]) { |lengths, inches| lengths << length(:in).ceil }.join(','),
        plt_total_weight: packages.map(&:lbs).inject(0) { |sum, lbs| sum += lbs }.ceil,
        plt_width_list: packages.map(&:inches).inject([]) { |lengths, inches| lengths << width(:in).ceil }.join(',')
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
      else
        response = JSON.parse(response)
        error = response.dig('create_pens_rate_quote_response', 'create_pens_rate_quote_result', 'errors', 'message')
        if !error.blank?
          success = false
          message = error
        else
          result = response.dig('create_pens_rate_quote_response', 'create_pens_rate_quote_result')

          service_type = :standard
          api_service_type = result.dig('quote', 'transit_type')
          @conf.dig(:services, :mappable).each do |key, val|
            service_type = key if api_service_type.downcase.include?(val)
          end

          cost = result.dig('quote', 'gross_charge').sub(',', '').sub('.', '').to_i
          transit_days = service_type == :next_day_ltl ? 1 : nil # TODO: Detect correctly
          estimate_reference = result.dig('quote', 'quote_number')
          if cost
            rate_estimates = [
              RateEstimate.new(
                origin,
                destination,
                { scac: self.class.scac.upcase, name: self.class.name },
                service_type,
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
