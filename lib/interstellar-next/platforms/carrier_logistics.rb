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
    def find_bol(tracking_number, options = {})
      options = @options.merge(options)
      parse_document_response(:bol, tracking_number, options)
    end

    def find_bol_implemented?
      true
    end

    def find_pod(tracking_number, options = {})
      options = @options.merge(options)
      parse_document_response(:pod, tracking_number, options)
    end

    def find_pod_implemented?
      true
    end

    # Rates
    def find_rates(shipment:)
      validate_packages(shipment.packages, @options[:tariff])

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
    def parse_document_response(action, tracking_number, options = {})
      options = @options.merge(options)
      browser = Watir::Browser.new(*options[:watir_args])
      browser.goto(build_url(action))

      browser.text_field(name: 'wlogin').set(@options[:username])
      browser.text_field(name: 'wpword').set(@options[:password])
      browser.button(name: 'BtnAction1').click

      downcase_html = browser.html.downcase

      EXPIRED_CREDENTIALS_MESSAGES.each do |expired_credentials_message|
        if downcase_html.include?(expired_credentials_message.downcase)
          browser.close
          raise ExpiredCredentialsError
        end
      end

      INVALID_CREDENTIALS_MESSAGES.each do |invalid_credentials_message|
        if downcase_html.include?(invalid_credentials_message.downcase)
          browser.close
          raise InvalidCredentialsError
        end
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
        raise Interstellar::DocumentNotFoundError, "API Error: #{self.class.name}: Document not found"
      end

      url = nil
      browser.switch_window.use do
        url = browser.url
      end

      browser.close

      if url.include?('viewdoc.php')
        raise Interstellar::ResponseError, "API Error: #{self.class.name}: Documnent cannot be downloaded"
      elsif url == 'about:blank'
        raise Interstellar::ResponseError,
              "API Error: #{self.class.name}: Document cannot be downloaded - link leads to about:blank"
      end

      path = if options[:path].blank?
               File.join(Dir.tmpdir, "#{self.class.name} #{tracking_number} #{action.to_s.upcase}.pdf")
             else
               options[:path]
             end
      file = File.new(path, 'w')

      File.open(file.path, 'wb') do |file|
        URI.parse(url).open do |input|
          file.write(input.read)
        end
      rescue OpenURI::HTTPError
        raise Interstellar::DocumentNotFoundError, "API Error: #{self.class.name}: Document not found"
      end

      File.exist?(path) ? path : false
    end

    # Tracking
    def parse_city_state(str)
      return nil if str.blank?

      Location.new(
        city: str.split(', ')[0].titleize,
        state: str.split(', ')[1].upcase,
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_city_state_zip(str)
      return nil if str.blank?

      Location.new(
        city: str.split(', ')[0].titleize,
        state: str.split(', ')[1].split(' ')[0].upcase,
        zip_code: str.split(', ')[1].split(' ')[1],
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_date(date)
      date ? DateTime.strptime(date, '%m/%d/%Y %H:%M %p').to_s(:db) : nil
    end

    def parse_tracking_response(tracking_number)
      url = "#{build_url(:track)}wbtn=PRO&wpro1=#{tracking_number}"
      save_request({ url: })

      begin
        response = HTTParty.get(url)
        if !response.code == 200
          if response.code == 404
            raise Interstellar::ShipmentNotFoundError
          else
            raise Interstellar::ResponseError, "API Error: #{self.class.name}: HTTP #{response.code}"
          end
        end
      rescue StandardError
        raise Interstellar::ResponseError, "API Error: #{self.class.name}: Unknown response:\n#{response.inspect}"
      end

      raise Interstellar::ShipmentNotFoundError if response.body.downcase.include?('please enter a valid pro')

      html = Nokogiri::HTML(response.body)
      tracking_table = html.css('.newtables2')[0]

      if tracking_table.blank?
        status = "API Error: #{self.class.name}: Unknown response (missing tracking table):\n#{response.inspect}"
        warn status

        return TrackingResponse.new(
          true,
          nil,
          { html: html.to_s },
          carrier: "#{self.class.scac}, #{self.class.name}",
          html:,
          response: html.to_s,
          status:,
          type_code: nil,
          ship_time: nil,
          scheduled_delivery_date: nil,
          actual_delivery_date: nil,
          delivery_signature: nil,
          shipment_events: [],
          shipper_address: nil,
          origin: nil,
          destination: nil,
          tracking_number:,
          request: last_request
        )
      end

      actual_delivery_date = nil
      receiver_address = nil
      ship_time = nil
      shipper_address = nil

      shipment_events = []
      tracking_table.css('tr').reverse.each do |tr|
        next if tr.text.include?('shipment status')
        next if tr.css('td').blank?

        # Some carriers do not provide times 👎
        datetime_without_time_zone = if tr.css('td')[3].blank?
                                       "#{tr.css('td')[2].text} 12:00 AM".squish
                                     else
                                       "#{tr.css('td')[2].text} #{tr.css('td')[3].text}".squish
                                     end
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

        location = (parse_city_state(location.squish) if !location.blank? && location.downcase.include?(','))

        event = event_key
        datetime_without_time_zone = parse_date(datetime_without_time_zone)

        case event_key
        when :delivered
          actual_delivery_date = datetime_without_time_zone
          receiver_address = location
        when :picked_up
          shipper_address = location
          ship_time = datetime_without_time_zone
        end

        # status and type_code set automatically by ActiveFreight based on event
        shipment_events << ShipmentEvent.new(event, datetime_without_time_zone, location)
      end

      scheduled_delivery_date = nil
      status = shipment_events.last&.status

      shipment_events = shipment_events.sort_by(&:time)

      TrackingResponse.new(
        true,
        status,
        { html: html.to_s },
        carrier: "#{self.class.scac}, #{self.class.name}",
        html:,
        response: html.to_s,
        status:,
        type_code: status,
        ship_time:,
        scheduled_delivery_date:,
        actual_delivery_date:,
        delivery_signature: nil,
        shipment_events:,
        shipper_address:,
        origin: shipper_address,
        destination: receiver_address,
        tracking_number:,
        request: last_request
      )
    end

    # Rates
    def build_rate_params(shipment:)
      params = ''.dup
      params << 'xmlv=yes' # must be first
      params << '&quotenumber=YES'
      params << "&vdzip=#{shipment.destination.zip}"
      params << "&vozip=#{shipment.origin.zip}"
      params << "&xmlpass=#{@options[:password]}"
      params << "&xmluser=#{@options[:username]}"

      i = 0
      shipment.packages.each do |package|
        i += 1 # API starts at 1 (not 0)

        params << "&vclass[#{i}]=#{package.freight_class}"
        params << "&wpallets[#{i}]=#{package.packaging.pallet? ? package.quantity : 0}"
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
      success = true
      message = ''

      if !response
        success = false
        message = 'API Error: Unknown response'
      elsif !response.dig('error', 'errormessage').blank?
        error = response.dig('error', 'errormessage')
        raise Interstellar::InvalidCredentialsError if error.downcase.include?('invalid username/password')
        raise Interstellar::UnserviceableError, error if error.downcase.include?('is not available')
        raise Interstellar::UnserviceableError, error if error.downcase.include?('out of the serviceable area')

        success = false
        message = error
      else
        cost = response.dig('ratequote', 'quotetotal').delete(',').delete('.').to_i

        if overlength_fees_require_tariff?
          shipment.packages.each do |package|
            cost += overlength_fee(@options[:tariff], package)
          end
        end

        transit_days = response.dig('ratequote', 'busdays').to_i
        estimate_reference = response.dig('ratequote', 'quotenumber')

        if cost
          rate_estimates = [
            RateEstimate.new(
              carrier: self,
              carrier_name: self.class.name,
              currency: 'USD',
              estimate_reference:,
              scac: self.class.scac.upcase,
              service_name: :standard,
              shipment:,
              total_price: cost,
              transit_days:,
              with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
            )
          ]
        else
          success = false
          message = 'API Error: Cost is emtpy'
        end
      end

      RateResponse.new(
        success,
        message,
        response.to_hash,
        rates: rate_estimates,
        response:,
        request: last_request
      )
    end
  end
end
