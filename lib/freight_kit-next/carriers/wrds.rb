# frozen_string_literal: true

module FreightKit
  class WRDS < FreightKit::Carrier
    class << self
      def find_tracking_info_implemented?
        true
      end

      def pod_implemented?
        true
      end

      def required_credential_types
        %i[selenoid website]
      end

      def requirements
        %i[credentials]
      end
    end

    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Western Regional Delivery Service'
    @@scac = 'WRDS'

    # Documents
    def pod(tracking_number)
      parse_pod_response(tracking_number)
    end

    # Rates

    # Tracking
    def find_tracking_info(tracking_number)
      parse_tracking_response(tracking_number)
    end

    protected

    def build_url(action, *)
      "#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
    end

    def commit(action, options = {})
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
    def parse_document_response(url)
      document_response = DocumentResponse.new(request: URI.parse(url))

      begin
        response = HTTParty.get(url)
      rescue StandardError => e
        document_response.error = e
        return document_response
      end

      document_response.assign_attributes(content_type: response.headers['content-type'], data: response.body)
      document_response
    end

    def parse_pod_response(tracking_number)
      selenoid_credentials = fetch_credential(:selenoid)
      website_credentials = fetch_credential(:website)

      browser = Watir::Browser.new(*selenoid_credentials.watir_args)
      browser.goto(build_url(:pod))

      browser.text_field(name: 'ctl00$cphMain$txtUserName').set(website_credentials.username)
      browser.text_field(name: 'ctl00$cphMain$txtPassword').set(website_credentials.password)
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

      parse_document_response(image_url)
    end

    # Rates

    # Tracking

    def parse_api_city_state_zip(str)
      return if str.blank?

      Location.new(
        city: str.split(', ')[0].titleize,
        province: str.split(', ')[1].split[0].upcase,
        postal_code: str.split(', ')[1].split[1],
        country: ActiveUtils::Country.find('USA'),
      )
    end

    def parse_api_city_state(str)
      return if str.blank?

      Location.new(
        city: str[..-3].strip.titleize,
        province: str[-2..].upcase,
        country: ActiveUtils::Country.find('USA'),
      )
    end

    def parse_api_date(date, location)
      return if date.blank?

      local_date = ::Date.strptime(date, '%m/%d/%Y')
      Time.zone.local(local_date:, location:)
    end

    def parse_api_date_time(date_time, location)
      return if date_time.blank?

      local_date_time = ::Time.strptime(date_time, '%m/%d/%Y %l:%M:%S %p').to_fs(:db)
      Time.zone.local(local_date_time:, location:)
    end

    def parse_tracking_response(tracking_number)
      tracking_response = TrackingResponse.new(carrier: self)

      selenoid_credentials = fetch_credential(:selenoid)

      browser = Watir::Browser.new(*selenoid_credentials.watir_args)
      browser.goto(build_url(:track))

      browser.text_field(name: 'ctl00$cphMain$txtProNumber').set(tracking_number)
      browser.button(name: 'ctl00$cphMain$btnSearchProNumber').wait_until(&:present?).click
      browser.element(xpath: '/html/body/form/div[3]/div/div/table/tbody/tr[2]/td[1]/a').wait_until(&:present?).click

      tracking_response.response = browser.html

      html = browser.table(id: 'cphMain_grvLogNotes').inner_html
      html = Nokogiri::HTML(html)

      api_city_state_zip = browser.element(xpath: '/html/body/form/div[3]/table[2]/tbody/tr[14]/td[1]/span').text
      shipper_location = parse_api_city_state_zip(api_city_state_zip)

      api_city_state_zip = browser.element(xpath: '/html/body/form/div[3]/table[2]/tbody/tr[14]/td[2]/span').text
      receiver_location = parse_api_city_state_zip(api_city_state_zip)

      actual_delivery_date = nil
      delivery_appointment_scheduled = false
      scheduled_delivery_date = nil
      ship_time = nil

      shipment_events = []

      html.css('tr').each do |tr|
        next if tr.text.include?('DateNotes')

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
          api_city_state = event.downcase.split(@conf.dig(:events, :types, event_key)).last
          api_city_state = api_city_state.downcase.sub(event_key.to_s, '')
          api_city_state = api_city_state.gsub(',', '')

          location = api_city_state.downcase.include?('carrier') ? nil : parse_api_city_state(api_city_state)
        end

        api_date_time = tr.css('td')[0].text
        date_time = parse_api_date_time(api_date_time, location)

        actual_delivery_date = date_time if event_key == :delivered
        delivery_appointment_scheduled = true if event_key == :delivery_appointment_scheduled

        # API doesn't provide pickup information
        ship_time = date_time if event_key == :arrived_at_terminal && ship_time.blank?

        shipment_event = ShipmentEvent.new(date_time:, location:, type_code: event_key)
        shipment_events << shipment_event
      end

      # API doesn't provide appointment information on :delivery_appointment_scheduled
      if delivery_appointment_scheduled
        html.css('tr').each do |tr|
          next if tr.text.include?('DateNotes')
          next unless tr.css('td')[1].text.include?('Estimated Delivery Date')

          api_date = tr.css('td')[0].text.split&.first
          scheduled_delivery_date = parse_api_date(api_date, shipment_events.last.location)

          break
        end
      end

      browser.close

      # API events sometimes appear after delivered
      status = actual_delivery_date.blank? ? shipment_events.last&.type_code : :delivered

      tracking_response.assign_attributes(
        actual_delivery_date:,
        destination: receiver_location,
        origin: shipper_location,
        scheduled_delivery_date:,
        ship_time:,
        shipment_events:,
        status:,
        tracking_number:,
      )

      tracking_response
    end
  end
end
