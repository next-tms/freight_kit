# frozen_string_literal: true

module HyperCarrier
  class WRDS < HyperCarrier::Carrier
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

    # Rates

    # Tracking
    def find_tracking_info(tracking_number)
      parse_tracking_response(tracking_number)
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
        raise HyperCarrier::DocumentNotFound, "API Error: #{@@name}: Document not found"
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
      browser.button(name: 'ctl00$cphMain$btnSearchProNumber').click
      browser.element(xpath: '/html/body/form/div[3]/div/div/table/tbody/tr[2]/td[1]/a').click
      browser.element(xpath: '/html/body/form/div[3]/table[2]/tbody/tr[16]/td[2]/a').click

      image_url = nil
      browser.switch_window.use do
        page_count = browser.element(xpath: '/html/body/form/div[3]/b/span').text.strip.to_i
        (page_count - 1).times do
          browser.element(xpath: '/html/body/form/div[3]/input[2]').click
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

    def parse_date(date)
      date ? DateTime.strptime(date, '%m/%d/%Y %l:%M:%S %p').to_s(:db) : nil
    end

    def parse_tracking_response(tracking_number)
      browser = Watir::Browser.new(*options[:watir_args])
      browser.goto build_url(:track)

      browser.text_field(name: 'ctl00$cphMain$txtProNumber').set(tracking_number)
      browser.button(name: 'ctl00$cphMain$btnSearchProNumber').click
      browser.element(xpath: '/html/body/form/div[3]/div/div/table/tbody/tr[2]/td[1]/a').click

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

      ship_time = browser.element(
        xpath: '/html/body/form/div[3]/table[2]/tbody/tr[7]/td[2]/span'
      ).text
      ship_time = ship_time ? Date.strptime(ship_time, '%m/%d/%Y').to_s(:db) : nil

      shipment_events = []
      html.css('tr').each do |tr|
        next if tr.text.include?('DateNotes')

        datetime_without_time_zone = tr.css('td')[0].text
        event = tr.css('td')[1].text

        event_key = nil
        @conf.dig(:events, :types).each do |key, val|
          if event.downcase.include?(val) && !event.downcase.include?('estimated')
            event_key = key
            break
          end
        end
        next if event_key.blank?

        location = event.downcase.split(@conf.dig(:events, :types, event_key)).last
        location = location.downcase.sub(event_key.to_s, '')
        location = location.gsub(',', '')
        location = location.downcase.include?('carrier') ? nil : parse_city_state(location)

        event = event_key
        datetime_without_time_zone = parse_date(datetime_without_time_zone)

        # status and type_code set automatically by ActiveFreight based on event
        shipment_events << ShipmentEvent.new(event, datetime_without_time_zone, location)
      end

      scheduled_delivery_date = nil
      status = shipment_events.last&.status

      actual_delivery_date = browser.element(xpath: '/html/body/form/div[3]/table[2]/tbody/tr[9]/td[2]/span').text
      actual_delivery_date = actual_delivery_date ? Date.strptime(actual_delivery_date, '%m/%d/%Y').to_s(:db) : nil

      browser.close

      shipment_events = shipment_events.sort_by(&:time)

      TrackingResponse.new(
        true,
        status,
        { html: html.to_s },
        carrier: "#{@@scac}, #{@@name}",
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
  end
end
