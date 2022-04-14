# frozen_string_literal: true

module Interstellar
  class DPHE < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Dependable Highway Express'
    @@scac = 'DPHE'

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(10_000, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(8, :feet)
    end

    def overlength_fees_require_tariff?
      false
    end

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
      validate_packages(shipment.packages)

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit_soap(:rates, request))
    end

    def find_rates_implemented?
      true
    end

    # Tracking

    def find_tracking_info(tracking_number)
      request = build_tracking_request(tracking_number)
      parse_tracking_response(commit_soap(:track, request))
    end

    def find_tracking_info_implemented?
      true
    end

    protected

    def build_soap_header(_action)
      {
        authentication_header: {
          user_name: @options[:username],
          password: @options[:password]
        }
      }
    end

    def commit_soap(action, request)
      Savon.client(
        wsdl: request_url(action),
        convert_request_keys_to: :camelcase,
        env_namespace: :soap,
        element_form_default: :qualified
      ).call(
        @conf.dig(:api, :actions, action),
        message: request
      ).body.to_hash
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domains, action)}#{@conf.dig(:api, :endpoints, action)}"
    end

    def parse_amount(amount)
      negative = amount.include?('(') && amount.include?(')')

      %w[$ , ( )].each do |char|
        amount = amount.sub(char, '')
      end

      return 0 if amount.blank?

      amount = (amount.to_f * 100).to_i
      return amount unless negative

      amount * -1
    end

    # Documents

    def parse_document_response(action, tracking_number)
      document_response = DocumentResponse.new

      url = request_url(action)
      browser = Watir::Browser.new(*@options[:watir_args])

      browser.goto(url)

      credentials = {
        username: @options[:username],
        password: @options[:password]
      }

      browser.text_field(name: 'dnn$ctr1914$View$TextBox1').set(credentials[:username])
      browser.text_field(name: 'dnn$ctr1914$View$TextBox2').set(credentials[:password])
      browser.button(name: 'dnn$ctr1914$View$Button1').click

      if browser.html.downcase.include?('invalid username or password')
        browser.close

        document_response.error = InvalidCredentialsError.new
        return document_response
      end

      browser.text_field(name: 'ctl00$ContentPlaceHolder1$txtProNumber').set(tracking_number)
      browser.button(name: 'ctl00$ContentPlaceHolder1$btnSubmit').click

      begin
        browser
          .element(xpath: '//*[@id="ContentPlaceHolder1_GridView1"]/tbody/tr[2]/td[2]/a')
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

      unless @options.dig(:selenoid_options, :download_url).blank?
        download_url = "#{@options.dig(:selenoid_options, :download_url)}/#{browser.driver.session_id}"
        response = HTTParty.get("#{download_url}/?json")

        filename = CGI.escape(JSON.parse(response.body)&.last)
        url = "#{download_url}/#{filename}"

        document_request.request = URI.parse(url)

        begin
          response = HTTParty.get(url)
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
        return document_response
      end

      path = Dir.glob("#{tmpdir}/*.tif").max_by { |f| File.mtime(f) }

      unless File.exist?(path)
        document_response.error = Interstellar::ResponseError.new
        return document_response
      end

      data = File.read(path)
      content_type = Mimemagic.by_magic(data)

      browser.close

      document_response.assign_attributes(content_type:, data:)
      document_response
    end

    # Rates

    def build_rate_request(shipment:)
      country_codes = [shipment.destination.country.code(:alpha2).value, shipment.origin.country.code(:alpha2).value]

      if country_codes.reject { |c| c.upcase == 'US' }.any?
        raise UnserviceableError, "No service from #{shipment.origin.zip} to #{shipment.destination.zip}"
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

      shipment_detail = []
      shipment.packages.each do |package|
        shipment_detail << [package.quantity, package.freight_class, package.pounds(:total)].join('|')
      end
      shipment_detail = shipment_detail.join('|')

      request = {
        customer_code: @options[:account],
        origin_zip: shipment.origin.zip.to_s.upcase,
        destination_zip: shipment.destination.zip.to_s.upcase,
        shipment_detail:,
        rating_type: '', # per API documentation
        accessorials:
      }

      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:)
      raise ResponseError, 'Unknown response' if response.blank?

      error = response.dig(:get_rates_response, :get_rates_result, :return_line)
      error ||= response.dig(:get_rates_response, :get_rates_result, :rate_error)

      if error
        raise InvalidCredentialsError, error if error.downcase.include?('not a valid customer code')
        raise UnserviceableError, error if error.downcase.include?('not a direct service point')

        raise ResponseError, "API Error: #{error}" if error
      end

      quote_number = response.dig(:get_rates_response, :get_rates_result, :rate_quote_number)
      raise Interstellar::UnserviceableError if quote_number.blank?

      if response.dig(:get_rates_response, :get_rates_result, :totals).blank?
        raise Interstellar::ResponseError, 'API Error: Cost is empty'
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

      RateResponse.new(
        rates: [
          Rate.new(
            carrier_name: self.class.name,
            carrier: self,
            currency: 'USD',
            estimate_reference:,
            prices:,
            scac: self.class.scac.upcase,
            service_name: :standard,
            shipment:,
            transit_days:,
            with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
          )
        ],
        request: last_request,
        response:
      )
    end

    def shipment_detail_description(shipment_detail)
      return '' if shipment_detail[:description].blank?

      shipment_detail[:description].capitalize.squish
    end

    # Tracking

    def build_tracking_request(tracking_number)
      request = { pro_number: tracking_number }
      save_request(request)
      request
    end

    def parse_api_city_state(str)
      return nil if str.blank?

      Location.new(
        city: str.split(', ')[0].titleize,
        province: str.split(', ')[1].split(' ')[0].upcase,
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_api_city(str)
      return nil if str.blank?

      city = str.squish.strip.titleize
      province = case city
                 when 'Los Angeles'
                   'CA'
                 when 'Sacramento'
                   'CA'
                 when 'Redding'
                   'CA'
                 when 'West Sacramento'
                   'CA'
                 end
      country = ActiveUtils::Country.find('USA')

      Location.new(city:, province:, country:)
    end

    def parse_api_date_time(date_time, location)
      return nil if date_time.blank?

      local_date_time = ::DateTime.strptime(date_time, '%m/%d/%Y %l:%M:%S %p').to_fs(:db)
      DateTime.new(local_date_time:, location:)
    end

    def parse_location(comment, delimiters)
      return nil if comment.blank? || !comment.include?(delimiters[0]) || !comment.include?(delimiters[1])

      parts = comment.split(delimiters[0])[0].split(delimiters[1])[1].split(',')

      city = parts[0].squish.strip.titleize
      province = parts[1].squish.strip.upcase
      country = ActiveUtils::Country.find('USA')

      Location.new(city:, province:, country:)
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
        street: search_result[:shipperaddress]&.squish&.strip&.titleize,
        city: search_result[:shipper_city].squish.strip.titleize,
        province: search_result[:shipper_state].strip.upcase,
        postal_code: search_result[:shipper_zip].strip,
        country:
      )

      receiver_location = Location.new(
        street: search_result[:consaddress]&.squish&.strip&.titleize,
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

        @conf.dig(:events, :types).each do |key, val|
          if comment.downcase.include?(val)
            event_key = key
          else
            ['signed by', 'partner delivery'].each do |val|
              if comment.downcase.include?(val)
                event_key = :delivered
                break
              end
            end
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
  end
end
