# frozen_string_literal: true

module FreightKit
  class CarrierLogistics < Platform
    class << self
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

    include FreightKit::Trackable
    include FreightKit::Rateable

    # Documents

    def pod(tracking_number)
      query = build_tracking_request(tracking_number)
      response = commit(:track, query)
      parse_document_response(response, :pod)
    end

    def scanned_bol(tracking_number)
      query = build_tracking_request(tracking_number)
      response = commit(:track, query)
      parse_document_response(response, :bol)
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

    def commit(action, query)
      url = build_url(action, query:)
      save_request(url)

      HTTParty.get(url, logger: Logger.new($stdout))
    end

    def map_response_errors(response, not_found_error: DocumentNotFoundError)
      return ResponseError.new('Unknown response') if response.blank?

      webspeed_error = (response.is_a?(String) || response.is_a?(HTTParty::Response)) && response.include?('WebSpeed error')
      return ResponseError.new('Temporary error (WebSpeed error)') if webspeed_error

      return if response.code == 200

      response.code == 400 ? not_found_error.new : ResponseError.new("HTTP #{response.code}")
    end

    # Documents

    def parse_document_response(tracking_response, document_type)
      document_response = DocumentResponse.new
      document_response.error = map_response_errors(tracking_response)
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

    def build_tracking_request(tracking_number)
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
      tracking_response.error = map_response_errors(response, not_found_error: ShipmentNotFoundError)
      return tracking_response if tracking_response.error.present?

      response.deep_symbolize_keys!

      api_events = response.dig(:protrace, :shiphists, :shiphist)
      if api_events.blank?
        tracking_response.error = ResponseError.new('Empty response')
        return tracking_response
      end

      origin = Location.new(
        address1: response.dig(:protrace, :shipaddr)&.titleize,
        address2: response.dig(:protrace, :shipaddr2)&.titleize,
        city: response.dig(:protrace, :origcity)&.titleize,
        province: response.dig(:protrace, :origstate)&.upcase,
        country: ActiveUtils::Country.find('USA')
      )

      destination = Location.new(
        address1: response.dig(:protrace, :consaddr)&.titleize,
        address2: response.dig(:protrace, :consaddr2)&.titleize,
        city: response.dig(:protrace, :destcity)&.titleize,
        province: response.dig(:protrace, :deststate)&.upcase,
        country: ActiveUtils::Country.find('USA')
      )

      deldateiso = response.dig(:protrace, :deldateiso)
      actual_delivery_date = (parse_api_date(deldateiso, destination) if deldateiso.present?)

      estdeliverydateiso = response.dig(:protrace, :estdeliverydateiso)
      estdeliverytimestart = response.dig(:protrace, :estdeliverytimestart)
      estimated_delivery_date = if estdeliverydateiso.present? && estdeliverytimestart.present?
                                  parse_api_date_time([estdeliverydateiso, estdeliverytimestart].join(' '), destination)
                                elsif estdeliverydateiso.present?
                                  parse_api_date(estdeliverydateiso, destination)
                                end

      scheduled_delivery_date = nil
      ship_time = nil

      api_events = response.dig(:protrace, :shiphists, :shiphist)
      api_events = [api_events] if api_events.is_a?(Hash)

      last_location = origin

      shipment_events = api_events.reverse.map do |api_event|
        hist_code = api_event[:histcode]&.downcase
        next if hist_code.blank?

        event = conf.dig(:events, :types).key(hist_code)
        next if event.blank?

        remarks = api_event[:histremarks]

        location = if remarks.present? && remarks.match?(/, \w{2}/) # ends in state abbreviation
                     parse_api_city_state(api_event[:histremarks])
                   end

        location ||= case event
                     when :delivered then destination
                     when :departed then last_location
                     when :picked_up, :pickup_scheduled then origin
                     end

        date = api_event[:histdate]
        time = api_event[:histtime]

        date_time = if [date, time].all?(&:present?)
                      parse_api_date_time([date, time].join(' '), location)
                    elsif date.present?
                      parse_api_date(date, location)
                    end

        last_location = location

        ShipmentEvent.new(location:, date_time:, type_code: event)
      end

      shipment_events.compact!

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

    def build_rate_request(shipment:)
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

      if shipment.accessorials.present?
        serviceable_accessorials?(shipment.accessorials)

        shipment
        .accessorials
        .reject { |accessorial| conf.dig(:accessorials, :unquotable).include?(accessorial) }
        .each do |shipment_accessorial|
          conf_accessorial = conf.dig(:accessorials, :mappable, shipment_accessorial)

          case conf_accessorial
          when Array then accessorials += conf_accessorial
          when String then accessorials << conf_accessorial
          end
        end
      end

      calculated_accessorials = build_calculated_accessorials(shipment.packages, shipment.origin, shipment.destination)
      accessorials += calculated_accessorials unless calculated_accessorials.blank?

      accessorials.uniq.compact.each { |accessorial| query[accessorial] = 'Yes' } if accessorials.any?

      query
    end

    def parse_rate_response(shipment:, response:)
      rate_response = RateResponse.new(request: last_request, response:)

      rate_response.error = map_response_errors(response)
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
