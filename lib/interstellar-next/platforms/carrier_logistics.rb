# frozen_string_literal: true

module Interstellar
  class CarrierLogistics < Platform
    class << self
      def find_rates_implemented?
        true
      end

      def find_tracking_info_implemented?
        true
      end

      def pod_implemented?
        true
      end

      def scanned_bol_implemented?
        true
      end

      def required_credential_types
        %i[api]
      end

      def requirements
        return %i[credentials tariff] if overlength_fees_require_tariff?

        %i[credentials]
      end
    end

    REACTIVE_FREIGHT_PLATFORM = true

    EXPIRED_CREDENTIALS_MESSAGES = [
      'Your password has expired'
    ].freeze
    INVALID_CREDENTIALS_MESSAGES = [
      'Unable to log in',
      'Your Username or Password is Incorrect'
    ].freeze

    # Documents

    def pod(tracking_number)
      query = build_tracking_query(tracking_number)
      response = commit(:track, query:)
      parse_document_response(response, :pod)
    end

    def scanned_bol(tracking_number)
      query = build_tracking_query(tracking_number)
      response = commit(:track, query:)
      parse_document_response(response, :bol)
    end

    # Rates

    def find_rates(shipment:)
      begin
        validate_packages(shipment.packages, tariff)
      rescue UnserviceableError => e
        return RateResponse.new(error: e)
      end

      query = build_rate_query(shipment:)
      response = commit(:rates, query:)
      parse_rate_response(shipment:, response:)
    end

    # Tracking

    def find_tracking_info(tracking_number)
      query = build_tracking_query(tracking_number)
      response = commit(:track, query:)
      parse_tracking_response(tracking_number, response:)
    end

    # protected

    def build_url(action, query:)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'

      uri = URI.parse("#{scheme}#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}")
      uri.query = query.to_query
      url = uri.to_s
      return url unless url.include?('@CARRIER_CODE@')

      url.sub('@CARRIER_CODE@', @conf.dig(:api, :carrier_code))
    end

    def commit(action, query:)
      url = build_url(action, query:)
      save_request(url)

      HTTParty.get(url, logger: Logger.new($stdout))
    end

    # Documents

    def parse_document_response(tracking_response, document_type)
      document_response = DocumentResponse.new

      document_response.error = case tracking_response.code
                                when 200 then nil
                                when 400 then DocumentNotFoundError.new
                                else
                                  ResponseError.new("HTTP #{tracking_response.code}")
                                end

      return document_response if document_response.error.present?

      tracking_response.deep_symbolize_keys!

      image_type_code = case document_type
                        when :bol then 'B'
                        when :pod then 'P'
                        end

      api_images = tracking_response.dig(:protrace, :images, :image)
      api_images = [api_images] if api_images.is_a?(Hash)

      image = api_images&.find { |image| image[:imagetypecode] == image_type_code }
      url = image.blank? ? nil : (image[:directurl].presence || image[:imageurl])

      if url.blank?
        document_response.error = DocumentNotFoundError.new
        return document_response
      end

      begin
        response = HTTParty.get(url)
      rescue StandardError => e
        document_response.error = e
        return document_response
      end

      unless response.code == 200
        document_response.error = DocumentNotFoundError.new
        return document_response
      end

      document_response.assign_attributes(content_type: response.headers['content-type'], data: response.body)
      document_response
    end

    # Tracking

    def build_tracking_query(tracking_number)
      api_credentials = fetch_credential(:api)

      { pronum: tracking_number, xmlpass: api_credentials.password, xmluser: api_credentials.username }
    end

    def parse_api_city_state(str)
      return nil if str.blank?

      city = str.split(', ')[0].titleize
      province = str.split(', ')[1].upcase

      if province == '*'
        province = case city
                   when 'Albuquerque' then 'NM'
                   end
      end

      Location.new(
        city:,
        province:,
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_api_city_state_zip(str)
      return nil if str.blank?

      parts = str.split(', ')

      Location.new(
        city: parts.first.titleize,
        province: parts.last.upcase,
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_api_date(date, location)
      return nil if date.blank?

      separator = %w[? -].find { |separator| date.include?(separator) }
      return nil unless separator.present?

      format = case date
               when /^\d{4}#{separator}/
                 %w[%Y %m %d].join(separator)
               when /^\d{2}#{separator}/
                 %w[%m %d %Y].join(separator)
               end
      return nil unless format.present?

      local_date = ::Date.strptime(date, format)
      DateTime.new(local_date:, location:)
    end

    def parse_api_date_time(date_time, location)
      return nil if date_time.blank?

      local_date_time = ::DateTime.strptime(date_time, '%Y-%m-%d %H:%M').to_fs(:db)
      DateTime.new(local_date_time:, location:)
    rescue Date::Error
      raise unless local_date_time.blank?

      parse_api_date(local_date_time, location)
    end

    def parse_tracking_response(tracking_number, response:)
      tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)

      tracking_response.error = case response.code
                                when 200 then nil
                                when 400 then ShipmentNotFoundError.new
                                else
                                  ResponseError.new("HTTP #{response.code}")
                                end

      return tracking_response if tracking_response.error.present?

      begin
        response.deep_symbolize_keys!
      rescue NoMethodError => e
        # There are instances that the HTTP Response returns a 200 response but returns an
        # error message e.g <TITLE>WebSpeed error from messenger process (6019)</TITLE> HTTPOK 200
        tracking_response.error = ResponseError.new("HTTP #{response}")
      end

      return tracking_response if tracking_response.error.present?

      api_events = response.dig(:protrace, :shiphists, :shiphist)
      if api_events.blank?
        tracking_response.error = ResponseError.new('Empty response')
        return tracking_response
      end

      actual_delivery_date = nil
      destination = nil
      estimated_delivery_date = nil
      origin = nil
      scheduled_delivery_date = nil
      ship_time = nil

      api_events = response.dig(:protrace, :shiphists, :shiphist)
      api_events = [api_events] if api_events.is_a?(Hash)

      shipment_events = api_events.map do |api_event|
        api_event_key = api_event[:histcode].downcase

        event = nil
        conf.dig(:events, :types).each_key do |key|
          next unless conf.dig(:events, :types, key) == api_event_key

          event = key
        end

        next if event.blank?

        location = if api_event[:histremarks].match?(/, \w{2}/) # ends in state abbreviation
                     parse_api_city_state(api_event[:histremarks])
                   end

        date_time = if api_event[:histdate].present? && api_event[:histtime].present?
                      parse_api_date_time("#{api_event[:histdate]} #{api_event[:histtime]}", location)
                    else
                      parse_api_date(api_event[:histdate], location)
                    end

        case event
        when :delivered
          actual_delivery_date = date_time
          estimated_delivery_date = actual_delivery_date
          destination = location
        when :picked_up
          origin = location
          ship_time = date_time
        end

        ShipmentEvent.new(location:, date_time:, type_code: event)
      end
      shipment_events.compact!
      shipment_events.reverse!

      status = shipment_events.last&.type_code

      tracking_response.assign_attributes(
        actual_delivery_date:,
        destination:,
        estimated_delivery_date:,
        origin:,
        scheduled_delivery_date:,
        ship_time:,
        shipment_events:,
        status:,
        tracking_number:
      )

      tracking_response
    end

    # Rates

    def parse_amount(amount)
      negative = amount.include?('-')

      %w[$ , -].each do |char|
        amount = amount.sub(char, '')
      end

      return 0 if amount.blank?

      amount = (amount.to_f * 100).to_i
      return amount unless negative

      amount * -1
    end

    def ratequote_line_description(ratequote_line)
      description = ratequote_line['chargedesc'] || ''
      description = description.capitalize

      code = ratequote_line['chargecode']&.upcase || ''
      description = "#{description} (#{code})" unless code.blank?

      description.squish
    end

    def build_rate_query(shipment:)
      api_credentials = fetch_credential(:api)

      query = {
        xmlv: 'yes', # must be first
        quotenumber: 'YES',
        vdzip: shipment.destination.postal_code,
        vozip: shipment.origin.postal_code,
        xmlpass: api_credentials.password,
        xmluser: api_credentials.username
      }

      i = 0
      shipment.packages.each do |package|
        i += 1 # API starts at 1 (not 0)

        query["vclass[#{i}]"] = package.freight_class
        query["wpallets[#{i}]"] = package.quantity
        query["wpieces[#{i}]"] = package.quantity
        query["wweight[#{i}]"] = package.pounds(:total).ceil
      end

      accessorials = []
      unless shipment.accessorials.blank?
        serviceable_accessorials?(shipment.accessorials)
        shipment.accessorials.each do |a|
          next if @conf.dig(:accessorials, :unserviceable).include?(a)

          conf_acc = @conf.dig(:accessorials, :mappable)[a]

          case conf_acc
          when Array then conf_acc.each { |c| accessorials << c }
          when String then accessorials << conf_acc
          end
        end
      end

      calculated_accessorials = build_calculated_accessorials(shipment.packages, shipment.origin, shipment.destination)
      accessorials += calculated_accessorials unless calculated_accessorials.blank?

      accessorials.uniq.each { |accessorial| query[accessorial] = 'Yes' } if accessorials.any?

      query
    end

    def parse_rate_response(shipment:, response:)
      rate_response = RateResponse.new(request: last_request, response:)

      if response.blank?
        rate_response.error = ResponseError.new('Unknown response')
        return rate_response
      end

      if response.is_a?(String) && response&.include?('WebSpeed error')
        rate_response.error = ResponseError.new('Temporary error (WebSpeed error)')
        return rate_response
      end

      rate_response.error = case response.code
                            when 200 then nil
                            when 400 then DocumentNotFoundError.new
                            else
                              ResponseError.new("HTTP #{response.code}")
                            end

      return rate_response if rate_response.error.present?
      
      error = response.dig('error', 'errormessage')

      unless error.blank?
        rate_response.error = InvalidCredentialsError.new if error.downcase.include?('invalid username/password')

        if error.downcase.include?('is not available') || error.downcase.include?('out of the serviceable area')
          rate_response.error = UnserviceableError.new(error)
        end

        rate_response.error = ResponseError.new(error) if rate_response.error.blank?

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

      if self.class.overlength_fees_require_tariff?
        cents = 0

        shipment.packages.each do |package|
          cents += overlength_fee(tariff, package)
        end

        prices << Price.new(blame: :tariff, cents:, description: 'Overlength fees') unless cents.zero?
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
  end
end
