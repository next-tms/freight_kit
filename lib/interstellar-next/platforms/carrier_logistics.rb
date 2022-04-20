# frozen_string_literal: true

module Interstellar
  class CarrierLogistics < Platform
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
      parse_document_response(:pod, tracking_number)
    end

    def pod_implemented?
      true
    end

    def scanned_bol(tracking_number)
      parse_document_response(:bol, tracking_number)
    end

    def scanned_bol_implemented?
      true
    end

    # Rates

    def find_rates(shipment:)
      begin
        validate_packages(shipment.packages, @options[:tariff])
      rescue UnserviceableError => e
        return RateResponse.new(error: e)
      end

      params = build_rate_params(shipment:)
      parse_rate_response(shipment:, response: commit(:rates, params:))
    end

    def find_rates_implemented?
      true
    end

    # Tracking

    def find_tracking_info(tracking_number)
      parse_tracking_response(tracking_number)
    end

    def find_tracking_info_implemented?
      true
    end

    # protected

    def debug?
      return false if @options[:debug].blank?

      @options[:debug]
    end

    def build_url(action, options = {})
      options = @options.merge(options)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      url = ''.dup
      url << "#{scheme}#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
      url = url.sub('@CARRIER_CODE@', @conf.dig(:api, :carrier_code)) if url.include?('@CARRIER_CODE@')
      url << options[:params] unless options[:params].blank?
      url
    end

    def commit(action, options = {})
      options = @options.merge(options)
      url = build_url(action, params: options[:params])

      response = HTTParty.get(url, logger: Logger.new($stdout))
      response.parsed_response if response&.parsed_response
    end

    # Documents

    def parse_document_response(action, tracking_number)
      document_response = DocumentResponse.new

      browser = Watir::Browser.new(*@options[:watir_args])
      browser.goto(build_url(action))

      browser.text_field(name: 'wlogin').set(@options[:username])
      browser.text_field(name: 'wpword').set(@options[:password])
      browser.button(name: 'BtnAction1').click

      downcase_html = browser.html.downcase

      EXPIRED_CREDENTIALS_MESSAGES.each do |expired_credentials_message|
        next unless downcase_html.include?(expired_credentials_message.downcase)

        browser.close

        document_response.error = ExpiredCredentialsError.new
        return document_response
      end

      INVALID_CREDENTIALS_MESSAGES.each do |invalid_credentials_message|
        next unless downcase_html.include?(invalid_credentials_message.downcase)

        browser.close

        document_response.error = InvalidCredentialsError.new
        return document_response
      end

      browser.frameset.frames[1].text_field(id: 'menuquicktrack').set(tracking_number)
      browser.browser.frameset.frames[1].button(id: 'menusubmit').click

      element = if action == :bol
                  browser.frameset.frames[1].button(value: 'View Bill Of Lading Image')
                else
                  browser.frameset.frames[1].button(value: 'View Delivery Receipt Image')
                end
      if element.exists?
        element.click
      else
        browser.close

        document_response.error = DocumentNotFoundError.new
        return document_response
      end

      url = nil
      browser.switch_window.use do
        url = browser.url
      end

      browser.close

      if url.include?('viewdoc.php') || url == 'about:blank'
        document_response.error = ResponseError.new('Documnent cannot be downloaded')
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

    def parse_api_city_state(str)
      return nil if str.blank?

      Location.new(
        city: str.split(', ')[0].titleize,
        province: str.split(', ')[1].upcase,
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_api_city_state_zip(str)
      return nil if str.blank?

      Location.new(
        city: str.split(', ')[0].titleize,
        province: str.split(', ')[1].split(' ')[0].upcase,
        postal_code: str.split(', ')[1].split(' ')[1],
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_api_date(date, location)
      return nil if date.blank?

      local_date = ::Date.strptime(date, '%m/%d/%Y')
      DateTime.new(local_date:, location:)
    end

    def parse_api_date_time(date_time, location)
      return nil if date_time.blank?

      local_date_time = ::DateTime.strptime(date_time, '%m/%d/%Y %H:%M %p').to_fs(:db)
      DateTime.new(local_date_time:, location:)
    end

    def parse_tracking_response(tracking_number)
      url = "#{build_url(:track)}wbtn=PRO&wpro1=#{tracking_number}"
      tracking_response = TrackingResponse.new(carrier: self, request: url)

      save_request(url)

      begin
        response = HTTParty.get(url)
      rescue StandardError => e
        tracking_response.assign_attributes(e:)
      end

      case response.code
      when 400
        tracking_response.assign_attributes(error: ShipmentNotFoundError.new)
        return tracking_response
      else
        unless response.code == 200
          tracking_response.assign_attributes(error: ResponseError.new("HTTP #{response.code}"))
          return tracking_response
        end
      end

      tracking_response.error = ShipmentNotFoundError.new if response.body.downcase.include?('please enter a valid')

      return tracking_response unless tracking_response.error.blank?

      html = Nokogiri::HTML(response.body)
      tracking_table = html.css('.newtables2')[0]

      tracking_response.response = html

      if tracking_table.blank?
        tracking_response.error = ResponseError.new('Missing tracking table')

        return tracking_response
      end

      actual_delivery_date = nil
      estimated_delivery_date = nil
      destination = nil
      scheduled_delivery_date = nil
      ship_time = nil
      origin = nil

      shipment_events = []
      tracking_table.css('tr').reverse.each do |tr|
        next if tr.text.include?('shipment status')
        next if tr.css('td').blank?

        event = tr.css('td')[0].text
        location = tr.css('td')[1].text

        event_key = nil
        @conf.dig(:events, :types).each do |key, val|
          if event.downcase.include?(val) && !event.downcase.include?('estimated')
            event_key = key
            break
          end
        end
        next if event_key.blank?

        event = event_key

        location = (parse_api_city_state(location.squish) if !location.blank? && location.downcase.include?(','))

        # Some carriers do not provide times 👎
        date_time = if tr.css('td')[3].blank?
                      parse_api_date(tr.css('td')[2].text.squish.strip, location)
                    else
                      parse_api_date_time("#{tr.css('td')[2].text} #{tr.css('td')[3].text}".squish.strip, location)
                    end

        case event_key
        when :delivered
          actual_delivery_date = date_time
          destination = location
        when :picked_up
          origin = location
          ship_time = date_time
        end

        shipment_events << ShipmentEvent.new(location:, date_time:, type_code: event)
      end

      api_estimated_delivery_date = html.css('td.estdeldate')&.text&.split(',')&.last&.strip

      unless api_estimated_delivery_date.blank?
        estimated_delivery_date = parse_api_date(api_estimated_delivery_date, origin)
      end

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

    def build_rate_params(shipment:)
      params = ''.dup
      params << 'xmlv=yes' # must be first
      params << '&quotenumber=YES'
      params << "&vdzip=#{shipment.destination.postal_code}"
      params << "&vozip=#{shipment.origin.postal_code}"
      params << "&xmlpass=#{@options[:password]}"
      params << "&xmluser=#{@options[:username]}"

      i = 0
      shipment.packages.each do |package|
        i += 1 # API starts at 1 (not 0)

        params << "&vclass[#{i}]=#{package.freight_class}"
        params << "&wpallets[#{i}]=#{package.quantity}"
        params << "&wpieces[#{i}]=#{package.quantity}"
        params << "&wweight[#{i}]=#{package.pounds(:total).ceil}"
      end

      accessorials = []
      unless shipment.accessorials.blank?
        serviceable_accessorials?(shipment.accessorials)
        shipment.accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << @conf.dig(:accessorials, :mappable)[a]
          end
        end
      end

      calculated_accessorials = build_calculated_accessorials(shipment.packages, shipment.origin, shipment.destination)
      accessorials += calculated_accessorials unless calculated_accessorials.blank?

      unless accessorials.blank?
        accessorials.uniq!
        params << accessorials.join.split('&').uniq.join('&')
      end

      save_request({ params: })
      params
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

      if overlength_fees_require_tariff?
        cents = 0

        shipment.packages.each do |package|
          cents += overlength_fee(@options[:tariff], package)
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
