# frozen_string_literal: true

module HyperCarrier
  class CarrierLogistics < Platform
    REACTIVE_FREIGHT_CARRIER = true

    EXPIRED_CREDENTIALS_MESSAGES = [
      'Your password has expired'
    ]
    INVALID_CREDENTIALS_MESSAGES = [
      'Your Username or Password is Incorrect'
    ]

    # Documents
    def find_bol(tracking_number, options = {})
      options = @options.merge(options)
      parse_document_response(:bol, tracking_number, options)
    end

    def find_pod(tracking_number, options = {})
      options = @options.merge(options)
      parse_document_response(:pod, tracking_number, options)
    end

    # Rates
    def find_rates(origin, destination, packages, options = {})
      options = @options.merge(options)
      origin = Location.from(origin)
      destination = Location.from(destination)
      packages = Array(packages)

      params = build_rate_params(origin, destination, packages, options)
      parse_rate_response(origin, destination, packages, commit(:rates, params: params))
    end

    # Tracking
    def find_tracking_info(tracking_number)
      parse_tracking_response(tracking_number)
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

      response = HTTParty.get(url)
      response.parsed_response if response&.parsed_response
    end

    # Documents
    def parse_document_response(action, tracking_number, options = {})
      options = @options.merge(options)
      browser = Watir::Browser.new(:chrome, headless: !debug?)
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

      if action == :bol
        element = browser.frameset.frames[1].button(value: 'View Bill Of Lading Image')
        if element.exists?
          element.click
        else
          browser.close
          raise HyperCarrier::DocumentNotFound, "API Error: #{self.class.name}: Document not found"
        end
      else
        element = browser.frameset.frames[1].button(value: 'View Delivery Receipt Image')
        if element.exists?
          element.click
        else
          browser.close
          raise HyperCarrier::DocumentNotFound, "API Error: #{self.class.name}: Document not found"
        end
      end

      url = nil
      browser.switch_window.use do
        url = browser.url
        if url.include?('viewdoc.php')
          browser.close
          raise HyperCarrier::ResponseError, "API Error: #{self.class.name}: Documnent cannot be downloaded"
        end
      end

      browser.close

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
        raise HyperCarrier::DocumentNotFound, "API Error: #{self.class.name}: Document not found"
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
      date ? DateTime.strptime(date, '%m/%d/%Y %I:%M %p').to_s(:db) : nil
    end

    def parse_tracking_response(tracking_number)
      url = "#{build_url(:track)}wbtn=PRO&wpro1=#{tracking_number}"
      save_request({ url: url })

      begin
        response = HTTParty.get(url)
        if !response.code == 200
          if response.code == 404
            raise HyperCarrier::ShipmentNotFound
          else
            raise HyperCarrier::ResponseError, "API Error: #{self.class.name}: HTTP #{response.code}"
          end
        end
      rescue StandardError
        raise HyperCarrier::ResponseError, "API Error: #{self.class.name}: Unknown response:\n#{response.inspect}"
      end

      raise HyperCarrier::ShipmentNotFound if response.body.downcase.include?('please enter a valid pro')

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
          html: html,
          response: html.to_s,
          status: status,
          type_code: nil,
          ship_time: nil,
          scheduled_delivery_date: nil,
          actual_delivery_date: nil,
          delivery_signature: nil,
          shipment_events: [],
          shipper_address: nil,
          origin: nil,
          destination: nil,
          tracking_number: tracking_number,
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

        datetime_without_time_zone = "#{tr.css('td')[2].text} #{tr.css('td')[3].text}".squeeze
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

        location = (parse_city_state(location.squeeze) if !location.blank? && location.downcase.include?(','))

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
        html: html,
        response: html.to_s,
        status: status,
        type_code: status,
        ship_time: ship_time,
        scheduled_delivery_date: scheduled_delivery_date,
        actual_delivery_date: actual_delivery_date,
        delivery_signature: nil,
        shipment_events: shipment_events,
        shipper_address: shipper_address,
        origin: shipper_address,
        destination: receiver_address,
        tracking_number: tracking_number,
        request: last_request
      )
    end

    # Rates
    def build_rate_params(origin, destination, packages, options = {})
      options = @options.merge(options)
      params = ''.dup
      params << "xmlv=yes&xmluser=#{@options[:username]}"
      params << "&xmlpass=#{@options[:password]}"
      params << "&vozip=#{origin.to_hash[:postal_code]}"
      params << "&vdzip=#{destination.to_hash[:postal_code]}"

      i = 0
      packages.each do |package|
        i += 1 # API starts at 1 (not 0)
        params << "&wpieces[#{i}]=1"
        params << "&wpallets[#{i}]=1"
        params << "&vclass[#{i}]=#{package.freight_class}"
        params << "&wweight[#{i}]=#{package.pounds.ceil}"
      end

      accessorials = []
      unless options[:accessorials].blank?
        serviceable_accessorials?(options[:accessorials])
        options[:accessorials].each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << @conf.dig(:accessorials, :mappable)[a]
          end
        end
      end

      calculated_accessorials = build_calculated_accessorials(packages, origin, destination)
      accessorials = accessorials + calculated_accessorials unless calculated_accessorials.blank?

      unless accessorials.blank?
        accessorials.uniq!
        params << accessorials.join.split('&').uniq.join('&')
      end

      save_request({ params: params })
      params
    end

    def parse_rate_response(origin, destination, _packages, response)
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
