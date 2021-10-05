# frozen_string_literal: true

module Interstellar
  class DPHE < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Dependable Highway Express'
    @@scac = 'DPHE'

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

      request = build_rate_request(origin, destination, packages, options)
      parse_rate_response(origin, destination, commit_soap(:rates, request))
    end

    # Tracking

    def find_tracking_info(tracking_number)
      request = build_tracking_request(tracking_number)
      parse_tracking_response(commit_soap(:track, request))
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

    # Documents

    def parse_document_response(action, tracking_number, options = {})
      options = @options.merge(options)

      raise ArgumentError if !action || !tracking_number
      raise ArgumentError if options[:url] && !options[:selenoid]

      tmpdir = Dir.tmpdir

      options[:watir_args] = [:chrome, options: { prefs: {} }] if !options[:watir_args]
      options[:watir_args].each do |h|
        if h.is_a?(Hash)
          h.merge!(options: {prefs: {}}) unless h.dig(:options, :prefs)
          if !options[:selenoid_options]
            h[:options][:prefs].merge!(
              download: {
                prompt_for_download: false,
                default_directory: tmpdir
              }
            )
          else
            h[:options][:prefs].merge!(
              download: {
                directory_upgrade: true,
                prompt_for_download: false
              }
            )
          end
        end
        h
      end

      url = request_url(action)
      browser = Watir::Browser.new(*options[:watir_args])
      
      browser.goto(url)

      credentials = {
        username: options[:username],
        password: options[:password]
      }

      browser.text_field(name: 'dnn$ctr1914$View$TextBox1').set(credentials[:username])
      browser.text_field(name: 'dnn$ctr1914$View$TextBox2').set(credentials[:password])
      browser.button(name: 'dnn$ctr1914$View$Button1').click

      if browser.html.downcase.include?('invalid username or password')
        browser.close
        raise InvalidCredentialsError
      end

      browser.text_field(name: 'ctl00$ContentPlaceHolder1$txtProNumber').set(tracking_number)
      browser.button(name: 'ctl00$ContentPlaceHolder1$btnSubmit').click

      begin
        browser
          .element(xpath: '//*[@id="ContentPlaceHolder1_GridView1"]/tbody/tr[2]/td[2]/a')
          .click
      rescue Watir::Exception::UnknownObjectException
        raise Interstellar::DocumentNotFound, "API Error: #{@@name}: Document not found"
      end
      
      browser.switch_window      
      button_xpath = case action
                     when :bol then '//*[@id="ContentPlaceHolder1_btnDocs"]'
                     when :pod then '//*[@id="ContentPlaceHolder1_btnPOD"]'
                     else
                       nil
                     end

      if !button_xpath || !browser.element(xpath: button_xpath).exists?
        browser.close
        raise Interstellar::DocumentNotFound
      end

      browser.element(xpath: button_xpath).click

      if !button_xpath || browser.element(xpath: button_xpath).innertext.downcase.include?('unavailable')
        browser.close
        raise Interstellar::DocumentNotFound
      end

      sleep(10) # so Chrome can finish downloading

      tif_path = nil
      if !options.dig(:selenoid_options, :download_url)
        tif_path = Dir.glob("#{tmpdir}/*.tif").max_by {|f| File.mtime(f)}
      else
        download_url = "#{options.dig(:selenoid_options, :download_url)}/#{browser.driver.session_id}"
        response = HTTParty.get("#{download_url}/?json")
        tif_url = "#{download_url}/#{JSON.parse(response.body)&.last}"
        tif_path = File.join(tmpdir, "#{tracking_number}_#{DateTime.current.to_s}.tif")

        File.open(tif_path, 'wb') do |file|
          HTTParty.get(tif_url, stream_body: true) do |fragment|
            file.write(fragment)
          end
        end
      end

      browser.close

      return Interstellar::ResponseError if !File.exist?(tif_path)

      path = if options[:path].blank?
               File.join(Dir.tmpdir, "#{self.class.name} #{tracking_number} #{action.to_s.upcase}.pdf")
             else
               options[:path]
             end
      file = File.new(path, 'w')
      
      file = Magick::ImageList.new(tif_path)
      file.write(path)

      return File.exist?(path) ? path : false
    end

    # Rates

    def build_rate_request(origin, destination, packages, options = {})
      options = @options.merge(options)

      accessorials = []
      unless options[:accessorials].blank?
        serviceable_accessorials?(options[:accessorials])
        options[:accessorials].each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << @conf.dig(:accessorials, :mappable)[a]
          end
        end
      end

      longest_dimension = packages.inject([]) { |_arr, p| [p.length(:in), p.width(:in)] }.max.ceil
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
      packages.each do |package|
        shipment_detail << "1|#{package.freight_class}|#{package.pounds.ceil}"
      end
      shipment_detail = shipment_detail.join('|')

      request = {
        customer_code: @options[:account],
        origin_zip: origin.to_hash[:postal_code].to_s.upcase,
        destination_zip: destination.to_hash[:postal_code].to_s.upcase,
        shipment_detail: shipment_detail,
        rating_type: '', # per API documentation
        accessorials: accessorials
      }

      save_request(request)
      request
    end

    def parse_rate_response(origin, destination, response)
      success = true
      message = ''

      if !response
        success = false
        message = 'API Error: Unknown response'
      else
        error = response.dig(:get_rates_response, :get_rates_result, :rate_error)
        quote_number = response.dig(:get_rates_response, :get_rates_result, :rate_quote_number).blank?

        # error on its own isn't reliable indicator of error - returns false on error
        if !error.blank? || quote_number
          success = false
          message = response.dig(:get_rates_response, :get_rates_result, :return_line)
        else
          cost = response.dig(:get_rates_response, :get_rates_result, :totals)
          if cost
            cost = cost.sub('$', '').sub(',', '').sub('.', '').to_i
            transit_days = response.dig(:get_rates_response, :get_rates_result, :transit_days).to_i
            estimate_reference = response.dig(:get_rates_response, :get_rates_result, :rate_quote_number)

            rate_estimates = [
              RateEstimate.new(
                origin,
                destination,
                { scac: self.class.scac.upcase, name: self.class.name },
                :standard,
                transit_days: transit_days,
                estimate_reference: estimate_reference,
                total_cost: cost,
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

    # Tracking

    def build_tracking_request(tracking_number)
      request = { pro_number: tracking_number }
      save_request(request)
      request
    end

    def parse_city_state(str)
      return nil if str.blank?

      Location.new(
        city: str.split(', ')[0].titleize,
        state: str.split(', ')[1].split(' ')[0].upcase,
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_city(str)
      return nil if str.blank?

      Location.new(
        city: str.squeeze.strip.titleize,
        state: nil,
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_date(date)
      date ? DateTime.strptime(date, '%m/%d/%Y %l:%M:%S %p').to_s(:db) : nil
    end

    def parse_location(comment, delimiters)
      return nil if comment.blank? || !comment.include?(delimiters[0]) || !comment.include?(delimiters[1])
      parts = comment.split(delimiters[0])[0].split(delimiters[1])[1].split(',')

      city = parts[0].squeeze.strip.titleize
      state = parts[1].squeeze.strip.upcase

      Location.new(
        city: city,
        province: state,
        state: state,
        country: ActiveUtils::Country.find('USA')
      )
    end

    def parse_tracking_response(response)
      raise Interstellar::ShipmentNotFound if response.dig(:get_tracking_response, :get_tracking_result, :tracking_status_response).blank?

      search_result = response.dig(:get_tracking_response, :get_tracking_result)

      shipper_address = Location.new(
        street: search_result.dig(:shipperaddress).squeeze.strip.titleize,
        city: search_result.dig(:shipper_city).squeeze.strip.titleize,
        state: search_result.dig(:shipper_state).strip.upcase,
        postal_code: search_result.dig(:shipper_zip).strip,
        country: ActiveUtils::Country.find('USA')
      )

      receiver_address = Location.new(
        street: search_result.dig(:consaddress).squeeze.strip.titleize,
        city: search_result.dig(:cons_city).squeeze.strip.titleize,
        state: search_result.dig(:cons_state).strip.upcase,
        postal_code: search_result.dig(:cons_zip).strip,
        country: ActiveUtils::Country.find('USA')
      )

      actual_delivery_date = parse_date(search_result.dig('Shipment', 'DeliveredDateTime'))
      pickup_date = parse_date(search_result.dig(:pickup_date))
      scheduled_delivery_date = parse_date(search_result.dig('Shipment', 'ApptDateTime'))
      tracking_number = search_result.dig('Shipment', 'SearchItem')

      shipment_events = []
      shipment_events << ShipmentEvent.new(
        :picked_up,
        pickup_date,
        shipper_address
      )

      api_events = search_result.dig(:tracking_status_response, :tracking_status_row).reverse
      api_events.each do |api_event|
        event_key = nil
        comment = api_event.dig(:tracking_status)

        @conf.dig(:events, :types).each do |key, val|
          if comment.downcase.include?(val)
            event_key = key
            break
          end
        end
        next if event_key.blank?

        case event_key
        when :arrived_at_terminal
          location = parse_city(comment.split('arrived')[1].upcase.split('SERVICE CENTER')[0])
        when :delivered
          location = parse_city_state(comment.split('in ')[1].split('completed')[0])
        when :departed
          location = parse_city(comment.split('departed')[1].upcase.split('SERVICE CENTER')[0])
        when :out_for_delivery
          location = receiver_address
        when :trailer_closed
          location = parse_city(comment.split('Location:')[1])
        when :trailer_unloaded
          location = parse_city(comment.split('Location:')[1])
        end

        datetime_without_time_zone = parse_date(api_event.dig(:tracking_date))

        # status and type_code set automatically by ActiveFreight based on event
        shipment_events << ShipmentEvent.new(event_key, datetime_without_time_zone, location)
      end

      shipment_events = shipment_events.sort_by(&:time)

      TrackingResponse.new(
        true,
        shipment_events.last&.status,
        response,
        carrier: "#{@@scac}, #{@@name}",
        hash: response,
        response: response,
        status: status,
        type_code: shipment_events.last&.status,
        ship_time: parse_date(search_result.dig('Shipment', 'ProDateTime')),
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
