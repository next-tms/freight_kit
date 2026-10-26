module FreightKit
  module Carriers
    class WesternRegionalDeliveryService < FreightKit::Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Fullerton',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '5f1f7d5d-f3e5-4374-abbd-0af6add7c721',
              postal_code: '92831',
              region_abbreviation: 'CA',
              street: '1424 S Raymond Ave'
            )
          ]
        end

        def contacts
          [Contact.new(department: 'Main', id: '5b751746-c141-4fa7-b841-370845f83a96', phone: '+17146832300')]
        end

        def headquarters
          Address.new(
            city: 'Fullerton',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '28de0284-8f3a-47dd-bb43-badc1942a4ef',
            postal_code: '92831',
            region_abbreviation: 'CA',
            street: '1424 South Raymond Ave'
          )
        end

        def id = '2d9b9c4c-717e-4832-8c14-2c4e56b01ae7'
        def legal_name = 'South Coast Transportation & Dist. , Inc.'
        def name = 'Western Regional Delivery Service'
        def required_credential_types = %i[selenoid website]
        def requirements = %i[credentials]
        def scac = 'WRDS'
        def services = %i[standard]
        def us_dot_number = 1_015_896
        def us_mc_number = 424_156
      end

      API = {
        domain: 'tracking.wrds.com',
        endpoints: { pod: '/zLogin.aspx', track: '/zTrack2.aspx' },
        methods: { track: :post },
        use_ssl: { bol: false, pod: false, track: true }
      }.freeze
      EVENTS = {
        types: {
          arrived_at_terminal: 'arrived',
          delivered: 'delivered',
          delivery_appointment_scheduled: 'delivery appt made',
          departed: 'departed'
        }
      }.freeze

      # Tracking
      def find_tracking_info(tracking_number) = parse_tracking_response(tracking_number)

      # Documents
      def pod(tracking_number) = parse_pod_response(tracking_number)

      protected

      def build_url(action, *) = "#{API[:domain]}#{API.dig(:endpoints, action)}"

      def commit(action, options = {})
        url = request_url(action)

        response = if API.dig(:methods, action) == :post
                     options[:params].blank? ? HTTPClient.post(url) : HTTPClient.post(url, query: options[:params])
                   else
                     HTTPClient.get(url)
                   end

        response.parsed_response if response&.parsed_response
      end

      def parse_api_city_state(str)
        return if str.blank?

        Location.new(
          city: str[..-3].strip.titleize,
          province: str[-2..].upcase,
          country: ActiveUtils::Country.find('USA')
        )
      end

      def parse_api_city_state_zip(str)
        return if str.blank?

        Location.new(
          city: str.split(', ')[0].titleize,
          province: str.split(', ')[1].split[0].upcase,
          postal_code: str.split(', ')[1].split[1],
          country: ActiveUtils::Country.find('USA')
        )
      end

      def parse_api_date(date, location)
        return if date.blank?

        local_date = ::Date.strptime(date, '%m/%d/%Y')
        ::FreightKit::DateTime.new(local_date:, location:)
      end

      def parse_api_date_time(date_time, location)
        return if date_time.blank?

        local_date_time = ::Time.strptime(date_time, '%m/%d/%Y %l:%M:%S %p').to_fs(:db)
        ::FreightKit::DateTime.new(local_date_time:, location:)
      end

      # Documents
      def parse_document_response(url)
        document_response = DocumentResponse.new(request: URI.parse(url))

        begin
          response = HTTPClient.get(url)
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

          EVENTS[:types].each do |key, val|
            if event.downcase.include?(val) && !event.downcase.include?('estimated')
              event_key = key
              break
            end
          end

          next if event_key.blank?

          location = nil

          unless event_key == :delivery_appointment_scheduled
            api_city_state = event.downcase.split(EVENTS.dig(:types, event_key)).last
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
            next if tr.css('td')[1].text.exclude?('Estimated Delivery Date')

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
          tracking_number:
        )

        tracking_response
      end

      def request_url(action)
        scheme = API.dig(:use_ssl, action) ? 'https://' : 'http://'
        "#{scheme}#{API[:domain]}#{API.dig(:endpoints, action)}"
      end
    end
  end
end
