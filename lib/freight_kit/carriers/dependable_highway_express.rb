module FreightKit
  module Carriers
    class DependableHighwayExpress < FreightKit::Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '0e090486-7ea4-4d55-9a6c-7589275882ae', phone: '+13233629399')]
        end

        def headquarters
          Address.new(
            city: 'Los Angeles',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'ac1b703d-aa8e-4547-95bc-e9e85ddfb356',
            postal_code: '90023',
            region_abbreviation: 'CA',
            street: '2555 E Olympic Blvd'
          )
        end

        def id = 'd66c61eb-bda4-4574-80e2-3246786b831b'
        def legal_name = 'Dependable Highway Express Inc'

        def mappable_accessorials
          {
            amusement_park_delivery: 'LMD',
            amusement_park_pickup: 'LMP',
            appointment_delivery: 'NTD',
            appointment_pickup: 'NTP',
            athletic_facility_delivery: 'LMD',
            athletic_facility_pickup: 'LMP',
            cemetery_delivery: 'LMD',
            cemetery_pickup: 'LMP',
            church_delivery: 'LMD',
            church_pickup: 'LMP',
            construction_delivery: 'LMT',
            construction_pickup: 'LMT',
            farm_delivery: 'LMD',
            farm_pickup: 'LMP',
            fitness_center_delivery: 'LMD',
            fitness_center_pickup: 'LMP',
            golf_course_delivery: 'LMD',
            golf_course_pickup: 'LMP',
            grocery_store_delivery: 'LMD',
            grocery_store_pickup: 'LMP',
            hospital_delivery: 'LMD',
            hospital_pickup: 'LMP',
            hotel_delivery: 'LMD',
            hotel_pickup: 'LMP',
            inside_delivery: 'IND',
            inside_pickup: 'INP',
            jobsite_delivery: 'LMT',
            jobsite_pickup: 'LMT',
            liftgate_delivery: 'LGD',
            liftgate_pickup: 'LGP',
            mall_delivery: 'LMD',
            mall_pickup: 'LMP',
            marina_delivery: 'LMD',
            marina_pickup: 'LMP',
            military_site_delivery: 'LMD',
            military_site_pickup: 'LMP',
            mine_site_delivery: 'LMD',
            mine_site_pickup: 'LMP',
            motel_delivery: 'LMD',
            motel_pickup: 'LMP',
            nursing_home_delivery: 'LMD',
            nursing_home_pickup: 'LMP',
            park_delivery: 'LMD',
            park_pickup: 'LMP',
            prison_delivery: 'LMD',
            prison_pickup: 'LMP',
            ranch_delivery: 'LMD',
            ranch_pickup: 'LMP',
            reservation_delivery: 'LMD',
            reservation_pickup: 'LMP',
            residential_delivery: 'RDS',
            residential_pickup: 'RSP',
            resort_delivery: 'LMD',
            resort_pickup: 'LMP',
            restaurant_delivery: 'LMD',
            restaurant_pickup: 'LMP',
            school_delivery: 'LMD',
            school_pickup: 'LMP',
            steel_mill_delivery: 'LMD',
            steel_mill_pickup: 'LMP',
            storage_facility_delivery: 'LMD',
            storage_facility_pickup: 'LMP',
            university_delivery: 'LMD',
            university_pickup: 'LMP'
          }
        end

        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(8, :feet)
        def name = 'Dependable Highway Express'
        def overlength_fees_require_tariff? = false
        def required_credential_types = %i[api selenoid website]
        def requirements = %i[credentials]
        def scac = 'DPHE'
        def services = %i[standard]
        def unquotable_accessorials = %i[dock_dropoff dock_pickup]

        def unserviceable_accessorials
          %i[
            afterhours_delivery
            afterhours_pickup
            airport_delivery
            airport_pickup
            brewery_delivery
            brewery_pickup
            convention_delivery
            convention_pickup
            customs_brokerage
            driver_assist
            early_morning_delivery
            fair_delivery
            fair_pickup
            flatbed_delivery
            flatbed_pickup
            government_delivery
            government_pickup
            grocery_warehouse_delivery
            grocery_warehouse_pickup
            guaranteed_delivery_am
            guaranteed_delivery_pm
            guaranteed_delivery
            inspection_site_delivery
            inspection_site_pickup
            utility_site_delivery
            utility_site_pickup
            winery_delivery
            winery_pickup
          ]
        end

        def us_dot_number = 9_853
      end

      include FreightKit::Rateable
      include FreightKit::Trackable

      API = {
        actions: { rates: :get_rates, track: :get_tracking },
        domains: {
          bol: 'apps.godependable.com',
          pod: 'apps.godependable.com',
          rates: 'www.godependable.com',
          track: 'www.godependable.com'
        },
        endpoints: {
          bol: '/CustomerLogin.aspx',
          pod: '/CustomerLogin.aspx',
          rates: '/services/rates.asmx?WSDL',
          track: '/services/track.asmx?WSDL'
        },
        use_ssl: { rates: false, track: false }
      }.freeze
      CITY_STATES = {
        ca: ['Los Angeles', 'Mammoth Lakes', 'Sacramento', 'Redding', 'West Sacramento'],
        nv: ['Reno', 'Sparks']
      }.freeze
      EVENTS = {
        types: {
          arrived_at_terminal: 'linehaul arrived',
          departed: 'linehaul departed',
          out_for_delivery: 'out for delivery',
          trailer_closed: 'terminal load',
          trailer_unloaded: 'terminal unload'
        }
      }.freeze

      # Documents

      def pod(tracking_number) = parse_document_response(:pod, tracking_number)
      def scanned_bol(tracking_number) = parse_document_response(:bol, tracking_number)

      protected

      def build_rate_request(shipment:)
        country_codes = [shipment.destination.country.code(:alpha2).value, shipment.origin.country.code(:alpha2).value]

        if country_codes.reject { |c| c.upcase == 'US' }.any?
          raise UnserviceableError,
                "No service from #{shipment.origin.postal_code} to #{shipment.destination.postal_code}"
        end

        accessorials = []
        if shipment.accessorials.present?
          serviceable_accessorials?(shipment.accessorials)
          shipment.accessorials.each do |a|
            accessorials << mappable_accessorials[a] if unserviceable_accessorials.exclude?(a)
          end
        end

        longest_dimension = shipment.packages.map { |p| [p.length(:in), p.width(:in)].max }.max.ceil
        if longest_dimension >= 336
          accessorials << 'X29'
        elsif longest_dimension >= 240 && longest_dimension < 336
          accessorials << 'X28'
        elsif longest_dimension >= 144 && longest_dimension < 240
          accessorials << 'X20'
        elsif longest_dimension >= 96 && longest_dimension < 144
          accessorials << 'X12'
        end

        accessorials = accessorials.uniq.join(',')

        shipment_detail = shipment.packages.map do |package|
          [package.quantity, package.freight_class, package.pounds(:total)].join('|')
        end.join('|')

        api_credentials = fetch_credential(:api)

        request = {
          customer_code: api_credentials.account,
          origin_zip: shipment.origin.postal_code.to_s.upcase,
          destination_zip: shipment.destination.postal_code.to_s.upcase,
          shipment_detail:,
          rating_type: '', # per API documentation
          accessorials:
        }

        save_request(request)
        request
      end

      def build_soap_header(_action)
        api_credentials = fetch_credential(:api)

        { authentication_header: { user_name: api_credentials.username, password: api_credentials.password } }
      end

      def build_tracking_request(tracking_number)
        request = { pro_number: tracking_number }
        save_request(request)
        request
      end

      def commit(action, request)
        client_args = {
          wsdl: request_url(action),
          convert_request_keys_to: :camelcase,
          env_namespace: :soap,
          element_form_default: :qualified
        }

        call_args = { message: request }

        response = ::FreightKit::SoapClient.new(
          carrier: self,
          action:,
          client_args:,
          call_args:,
          soap_operation: API.dig(:actions, action)
        ).call

        return response if response.is_a?(TrackingResponse) || response.is_a?(RateResponse)

        response.to_hash
      end

      def parse_amount(amount)
        negative = amount.include?('(') && amount.include?(')')

        ['$', ',', '(', ')'].each do |char|
          amount = amount.sub(char, '')
        end

        return 0 if amount.blank?

        amount = (amount.to_f * 100).to_i
        return amount unless negative

        amount * -1
      end

      def parse_api_city(str)
        return if str.blank?

        city = str.squish.strip.titleize
        province = nil
        country = ActiveUtils::Country.find('USA')

        CITY_STATES.each do |state, cities|
          if cities.include?(city)
            province = state.to_s.upcase
            break
          end
        end

        Location.new(city:, province:, country:)
      end

      def parse_api_city_state(str)
        return if str.blank?

        Location.new(
          city: str.split(', ')[0].titleize,
          province: str.split(', ')[1].split[0].upcase,
          country: ActiveUtils::Country.find('USA')
        )
      end

      def parse_api_date_time(date_time, location)
        return if date_time.blank?

        local_date_time = ::Time.strptime(date_time, '%m/%d/%Y %l:%M:%S %p').to_fs(:db)
        ::FreightKit::DateTime.new(local_date_time:, location:)
      end

      def parse_document_response(action, tracking_number)
        document_response = DocumentResponse.new

        selenoid_credential = fetch_credential(:selenoid)
        website_credentials = fetch_credential(:website)

        browser = Watir::Browser.new(*selenoid_credential.watir_args)

        browser.goto(request_url(action))

        browser.text_field(name: 'dnn$ctr1914$View$TextBox1').set(website_credentials.username)
        browser.text_field(name: 'dnn$ctr1914$View$TextBox2').set(website_credentials.password)
        browser.button(name: 'dnn$ctr1914$View$Button1').click

        if browser.html.downcase.include?('invalid username or password')
          browser.close

          document_response.error = InvalidCredentialsError.new
          return document_response
        end

        browser.text_field(name: 'ctl00$ContentPlaceHolder1$txtProNumber').set(tracking_number)
        browser.button(name: 'ctl00$ContentPlaceHolder1$btnSubmit').click

        begin
          browser.element(xpath: '//*[@id="ContentPlaceHolder1_GridView1"]/tbody/tr[2]/td[2]/a')
                 .click
        rescue Watir::Exception::UnknownObjectException
          document_response.error = DocumentNotFoundError.new
          return document_response
        end

        browser.switch_window
        button_xpath = case action
                       when :bol then '//*[@id="ContentPlaceHolder1_btnDocs"]'
                       when :pod then '//*[@id="ContentPlaceHolder1_btnPOD"]'
                       end

        if !button_xpath || !browser.element(xpath: button_xpath).exists?
          browser.close

          document_response.error = DocumentNotFoundError.new
          return document_response
        end

        browser.element(xpath: button_xpath).click

        if !button_xpath || browser.element(xpath: button_xpath).innertext.downcase.include?('unavailable')
          browser.close

          document_response.error = DocumentNotFoundError.new
          return document_response
        end

        sleep(10) # so Chrome can finish downloading

        download_url = "#{selenoid_credential.selenoid_options[:download_url]}/#{browser.driver.session_id}"
        response = HTTPClient.get("#{download_url}/?json")

        filename = URI.encode_www_form_component(JSON.parse(response.body)&.last)
        url = "#{download_url}/#{filename}"

        document_response.request = URI.parse(url)

        begin
          response = HTTPClient.get(url)
        rescue StandardError => e
          document_response.error = e
          return document_response
        end

        browser.close

        unless response.code == 200
          document_response.error = DocumentNotFoundError.new
          return document_response
        end

        document_response.assign_attributes(content_type: response.headers['content-type'], data: response.body)
        document_response
      end

      def parse_location(comment, delimiters)
        return if comment.blank? || !comment.include?(delimiters[0]) || !comment.include?(delimiters[1])

        parts = comment.split(delimiters[0])[0].split(delimiters[1])[1].split(',')

        city = parts[0].squish.strip.titleize
        province = parts[1].squish.strip.upcase
        country = ActiveUtils::Country.find('USA')

        Location.new(city:, province:, country:)
      end

      def parse_rate_response(shipment:, response:)
        rate_response = RateResponse.new(request: last_request, response:)

        if response.blank?
          rate_response.error = ResponseError.new('Unknown response')
          return rate_response
        end

        error = response.dig(:get_rates_response, :get_rates_result, :return_line)
        error ||= response.dig(:get_rates_response, :get_rates_result, :rate_error)

        if error
          message = error.downcase
          rate_response.error = InvalidCredentialsError.new(error) if message.include?('not a valid customer code')

          if message.include?('not a direct service point') || message.include?('lanes not serviced')
            rate_response.error = UnserviceableError.new(error)
          end

          rate_response.error = ResponseError.new(error) if rate_response.error.blank?
          return rate_response
        end

        quote_number = response.dig(:get_rates_response, :get_rates_result, :rate_quote_number)
        raise FreightKit::UnserviceableError if quote_number.blank?

        if response.dig(:get_rates_response, :get_rates_result, :totals).blank?
          rate_response.error = ResponseError.new('Cost is empty')
          return rate_response
        end

        transit_days = response.dig(:get_rates_response, :get_rates_result, :transit_days)&.to_i
        estimate_reference = response.dig(:get_rates_response, :get_rates_result, :rate_quote_number)

        prices = []

        shipment_details = response.dig(
          :get_rates_response,
          :get_rates_result,
          :shipment_detail_response,
          :shipment_detail_row
        )

        shipment_details.each do |shipment_detail|
          next if shipment_detail[:charge].blank?
          next if shipment_detail[:description] == 'Totals'

          cents = parse_amount(shipment_detail[:charge])
          description = shipment_detail_description(shipment_detail)

          prices << Price.new(blame: :api, cents:, description:)
        end

        rate = Rate.new(
          carrier_name: name,
          carrier: self,
          currency: 'USD',
          estimate_reference:,
          prices:,
          scac:,
          service_name: :standard,
          shipment:,
          transit_days:,
          with_excessive_length_fees: rates_with_excessive_length_fees?
        )

        rate_response.rates = [rate]
        rate_response
      end

      def parse_tracking_response(response)
        tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)

        if response.dig(:get_tracking_response, :get_tracking_result, :tracking_status_response).blank?
          tracking_response.error = ShipmentNotFoundError.new
          return tracking_response
        end

        search_result = response.dig(:get_tracking_response, :get_tracking_result)

        country = ActiveUtils::Country.find('USA')

        shipper_location = Location.new(
          address1: search_result[:shipperaddress]&.squish&.titleize,
          city: search_result[:shipper_city].squish.strip.titleize,
          province: search_result[:shipper_state].strip.upcase,
          postal_code: search_result[:shipper_zip].strip,
          country:
        )

        receiver_location = Location.new(
          address1: search_result[:consaddress]&.squish&.titleize,
          city: search_result[:cons_city].squish.strip.titleize,
          province: search_result[:cons_state].strip.upcase,
          postal_code: search_result[:cons_zip].strip,
          country:
        )

        api_date_time = search_result.dig('Shipment', 'DeliveredDateTime')
        actual_delivery_date = parse_api_date_time(api_date_time, receiver_location)

        api_date_time = search_result[:pickup_date]
        pickup_date = parse_api_date_time(api_date_time, shipper_location)

        api_date_time = search_result.dig('Shipment', 'ApptDateTime')
        scheduled_delivery_date = parse_api_date_time(api_date_time, receiver_location)

        ship_time = pickup_date
        tracking_number = search_result.dig('Shipment', 'SearchItem')

        shipment_events = []
        shipment_events << ShipmentEvent.new(location: shipper_location, date_time: pickup_date, type_code: :picked_up)

        api_events = search_result.dig(:tracking_status_response, :tracking_status_row).reverse
        api_events.each do |api_event|
          event_key = nil
          comment = api_event[:tracking_status]

          EVENTS[:types].each do |key, val|
            if comment.downcase.include?(val)
              event_key = key
            else
              ['signed by', 'partner delivery'].each { |val| event_key = :delivered if comment.downcase.include?(val) }
            end

            break if event_key
          end

          next if event_key.blank?

          location =  case event_key
                      when :arrived_at_terminal
                        parse_api_city(comment.split('arrived')[1].upcase.split('SERVICE CENTER')[0])
                      when :delivered
                        receiver_location
                      when :departed
                        parse_api_city(comment.split('departed')[1].upcase.split('SERVICE CENTER')[0])
                      when :out_for_delivery
                        receiver_location
                      when :trailer_closed
                        parse_api_city(comment.split('Location:')[1])
                      when :trailer_unloaded
                        parse_api_city(comment.split('Location:')[1])
                      end

          date_time = parse_api_date_time(api_event[:tracking_date], location)

          actual_delivery_date = date_time if event_key == :delivered

          shipment_events << ShipmentEvent.new(date_time:, location:, type_code: event_key)
        end

        status = shipment_events.last&.type_code

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
        "#{scheme}#{API.dig(:domains, action)}#{API.dig(:endpoints, action)}"
      end

      def shipment_detail_description(shipment_detail)
        return '' if shipment_detail[:description].blank?

        shipment_detail[:description].capitalize.squish
      end
    end
  end
end
