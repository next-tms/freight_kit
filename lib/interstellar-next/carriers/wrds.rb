# frozen_string_literal: true

module Interstellar
  class WRDS < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Western Regional Delivery Service'
    @@scac = 'WRDS'

    def available_services
      nil
    end

    def requirements
      %i[username password]
    end

    # Documents
    def find_pod(tracking_number, options = {})
      options = @options.merge(options)
      parse_pod_response(tracking_number, options)
    end

    def find_pod_implemented?
      true
    end

    # Rates

    # Tracking
    def find_tracking_info(tracking_number, options = {})
      options = @options.merge(options)
      parse_tracking_response(tracking_number, options)
    end

    def find_tracking_info_implemented?
      true
    end

    protected

    def build_url(action, *)
      url = "#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
    end

    def commit(action, options = {})
      options = @options.merge(options)
      url = request_url(action)

      response = if @conf.dig(:api, :methods, action) == :post
                   options[:params].blank? ? HTTParty.post(url) : HTTParty.post(url, query: options[:params])
                 else
                   HTTParty.get(url)
                 end

      response.parsed_response if response&.parsed_response
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
    end

    # Documents
    def parse_document_response(type, tracking_number, url, options = {})
      options = @options.merge(options)

      path = if options[:path].blank?
               File.join(Dir.tmpdir, "#{@@name} #{tracking_number} #{type.to_s.upcase}.pdf")
             else
               options[:path]
             end
      file = Tempfile.new(binmode: true)

      File.open(file.path, 'wb') do |file|
        URI.parse(url).open do |input|
          file.write(input.read)
        end
      rescue OpenURI::HTTPError
        raise Interstellar::DocumentNotFoundError, "API Error: #{@@name}: Document not found"
      end

      file = Magick::ImageList.new(file.path)
      file.write(path)
      File.exist?(path) ? path : false
    end

    def parse_pod_response(tracking_number, options = {})
      options = @options.merge(options)

      browser = Watir::Browser.new(*options[:watir_args])
      browser.goto(build_url(:pod))

      browser.text_field(name: 'ctl00$cphMain$txtUserName').set(@options[:username])
      browser.text_field(name: 'ctl00$cphMain$txtPassword').set(@options[:password])
      browser.button(name: 'ctl00$cphMain$btnLogIn').click

      if browser.html.include?('Username or password is invalid.')
        browser.close
        raise InvalidCredentialsError
      end

      browser.text_field(name: 'ctl00$cphMain$txtProNumber').set(tracking_number)
      browser.button(name: 'ctl00$cphMain$btnSearchProNumber').wait_until(&:present?).click
      browser.element(xpath: '/html/body/form/div[3]/div/div/table/tbody/tr[2]/td[1]/a').wait_until(&:present?).click
      browser.element(xpath: '/html/body/form/div[3]/table[2]/tbody/tr[16]/td[2]/a').wait_until(&:present?).click

      image_url = nil
      browser.switch_window.use do
        page_count = browser.element(xpath: '/html/body/form/div[3]/b/span').text.strip.to_i
        (page_count - 1).times do
          browser.element(xpath: '/html/body/form/div[3]/input[2]').wait_until(&:present?).click
        end
        image_url = browser.element(css: '#cphMain_imgImage').attribute_value('src')
      end
      browser.close

      parse_document_response(:pod, tracking_number, image_url, options)
    end

    # Rates

    # Tracking
    def parse_city_state_zip(str)
      return nil if str.blank?

      Location.new(
        city: str.split(', ')[0].titleize,
        state: str.split(', ')[1].split(' ')[0].upcase,
        zip_code: str.split(', ')[1].split(' ')[1],
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_city_state(str)
      return nil if str.blank?

      Location.new(
        city: str.split(' ')[0].titleize,
        state: str.split(' ')[1].upcase,
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_api_date_time(date_time)
      return nil if date_time.blank?

      local_date_time = ::DateTime.strptime(date_time, '%m/%d/%Y %l:%M:%S %p').to_fs(:db)
      DateTime.new(local_date_time:)
    end

    def parse_tracking_response(tracking_number, options = {})
      options = @options.merge(options)

      browser = Watir::Browser.new(*options[:watir_args])
      browser.goto build_url(:track)

      browser.text_field(name: 'ctl00$cphMain$txtProNumber').set(tracking_number)
      browser.button(name: 'ctl00$cphMain$btnSearchProNumber').wait_until(&:present?).click
      browser.element(xpath: '/html/body/form/div[3]/div/div/table/tbody/tr[2]/td[1]/a').wait_until(&:present?).click

      html = browser.table(id: 'cphMain_grvLogNotes').inner_html
      html = Nokogiri::HTML(html)

      shipper_address = parse_city_state_zip(
        browser.element(
          xpath: '/html/body/form/div[3]/table[2]/tbody/tr[14]/td[1]/span'
        ).text
      )

      receiver_address = parse_city_state_zip(
        browser.element(
          xpath: '/html/body/form/div[3]/table[2]/tbody/tr[14]/td[2]/span'
        ).text
      )

      actual_delivery_date = nil
      delivery_appointment_scheduled = false
      scheduled_delivery_date = nil
      ship_time = nil

      shipment_events = []

      html.css('tr').each do |tr|
        next if tr.text.include?('DateNotes')

        date_time = tr.css('td')[0].text
        event = tr.css('td')[1].text

        event_key = nil

        @conf.dig(:events, :types).each do |key, val|
          if event.downcase.include?(val) && !event.downcase.include?('estimated')
            event_key = key
            break
          end
        end

        next if event_key.blank?

        location = nil

        unless event_key == :delivery_appointment_scheduled
          location = event.downcase.split(@conf.dig(:events, :types, event_key)).last
          location = location.downcase.sub(event_key.to_s, '')
          location = location.gsub(',', '')
          location = location.downcase.include?('carrier') ? nil : parse_city_state(location)
        end

        date_time = parse_api_date_time(date_time)

        actual_delivery_date = date_time if event_key == :delivered
        delivery_appointment_scheduled = true if event_key == :delivery_appointment_scheduled

        # API doesn't provide pickup information
        if event_key == :arrived_at_terminal && (ship_time.blank? || ship_time.local_date_time > date_time.local_date_time)
          ship_time = date_time
        end

        shipment_event = ShipmentEvent.new(date_time:, location:, type_code: event_key)
        shipment_events << shipment_event
      end

      # API doesn't provide appointment information on :delivery_appointment_scheduled
      if delivery_appointment_scheduled
        html.css('tr').each do |tr|
          next if tr.text.include?('DateNotes')
          next unless tr.css('td')[1].text.include?('Estimated Delivery Date')

          scheduled_delivery_date = parse_api_date_time(tr.css('td')[0].text)
          break
        end
      end

      browser.close

      shipment_events = shipment_events.sort_by { |shipment_event| shipment_event.date_time.local_date_time }

      # API events sometimes appear after delivered
      status = actual_delivery_date.blank? ? shipment_events.last&.type_code : :delivered

      TrackingResponse.new(
        actual_delivery_date:,
        carrier: self,
        destination: receiver_address,
        origin: shipper_address,
        request: last_request,
        response: html.to_s,
        scheduled_delivery_date:,
        ship_time:,
        shipment_events:,
        shipper_address:,
        status:,
        tracking_number:
      )
    end
  end
end
