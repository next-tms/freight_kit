# frozen_string_literal: true

module Interstellar
  class BTVP < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Best Overnite Express'
    @@scac = 'BTVP'

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
      true
    end

    def requirements
      %i[username password]
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

    # Pickups

    def create_pickup(
      delivery_from:,
      delivery_to:,
      dispatcher:,
      pickup_from:,
      pickup_to:,
      scac:,
      service:,
      shipment:
    )
      parse_pickup_response(
        delivery_from:,
        delivery_to:,
        dispatcher:,
        pickup_from:,
        pickup_to:,
        scac:,
        service:,
        shipment:
      )
    end

    def create_pickup_implemented?
      true
    end

    # Rates

    def find_rates(shipment:)
      validate_packages(shipment.packages, @tariff)

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit(:rates, request))
    end

    def find_rates_implemented?
      true
    end

    # Tracking

    def find_tracking_info(tracking_number, *)
      request = build_tracking_request(tracking_number)
      parse_tracking_response(commit(:track, request))
    end

    def find_tracking_info_implemented?
      true
    end

    protected

    def build_soap_header
      {
        username: @options[:username],
        password: @options[:password]
      }
    end

    def commit(action, request)
      Savon.client(
        wsdl: build_url(action),
        convert_request_keys_to: :upcase,
        env_namespace: :soapenv
      ).call(
        @conf.dig(:api, :actions, action),
        headers: { 'SOAPAction' => '""' },
        soap_action: false,
        message: request
      ).body
    end

    def parse_api_date(date)
      return nil if date.blank?

      local_date = ::Date.strptime(date, '%m/%d/%Y')
      DateTime.new(local_date:)
    end

    def parse_api_date_time(date_time, location)
      return nil if date_time.blank?

      format = date_time.include?('-') ? '%Y-%m-%d %H:%M' : '%m/%d/%Y %H:%M'

      local_date_time = ::DateTime.strptime(date_time, format).to_fs(:db)
      DateTime.new(local_date_time:, location:)
    end

    def build_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domain)}:#{@conf.dig(:api, :ports, action)}#{@conf.dig(:api, :endpoints, action)}"
    end

    def strip_date(str)
      str ? str.split(/[A|P]M /)[1] : nil
    end

    # Documents

    def download_document(_type, _tracking_number, url)
      document_response = DocumentResponse.new(request: url)

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

    def parse_document_response(type, tracking_number)
      browser = Watir::Browser.new(*@options[:watir_args])
      browser.goto(build_url(:pod))

      browser.text_field(name: 'userid').set(@options[:username])
      browser.text_field(name: 'password').set(@options[:password])
      browser.button(name: 'btnLogin').click

      if browser.html.include?('You are not enrolled in any application environments on this server')
        browser.close
        raise Interstellar::InvalidCredentialsError,
              'You are not enrolled in any application environments on this server'
      end

      if browser.html.include?('You already have the maximum permitted application sessions open')
        browser.close
        raise Interstellar::ResponseError, 'You already have the maximum permitted application sessions open'
      end

      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[2]/img').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[3]/ul[2]/li').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[3]/ul[2]/li[6]/span[2]').wait_until(&:present?).click
      browser.select_list(name: 'TATIWT').select('S')

      browser.textarea(name: 'TATFB').set(tracking_number)
      browser.button(xpath: '/html/body/div[1]/div[3]/div[3]/div/div[1]/div/button[2]').click

      sleep(5)

      unless browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div[1]/div[4]/div[3]/div/table/tbody/tr[2]/td[2]').exists?
        browser.element(xpath: '/html/body/div[1]/div[1]/div[2]/div[4]').wait_until(&:present?).click
        browser.element(xpath: '/html/body/div[12]/div[11]/div/button[1]').wait_until(&:present?).click
        browser.close

        raise Interstellar::ShipmentNotFoundError
      end

      browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div[1]/div[4]/div[3]/div/table/tbody/tr[2]/td[2]').double_click

      sleep(5)

      unless browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div/div/form/div[4]/div[2]/div/div/table').exists?
        browser.element(xpath: '/html/body/div[1]/div[1]/div[2]/div[4]').wait_until(&:present?).click
        browser.element(xpath: '/html/body/div[12]/div[11]/div/button[1]').wait_until(&:present?).click
        browser.close

        raise Interstellar::DocumentNotFoundError
      end

      html = browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div/div/form/div[4]/div[2]/div/div/table').inner_html
      html = Nokogiri::HTML.parse(html)

      link_id = nil
      html.css('tr').each do |tr|
        next unless tr.text.downcase.include?(@conf.dig(:documents, :types, type).downcase)

        link_id = tr.css('td')[1].css('a').to_html.split('id=')[1].split('onfocus')[0].gsub('"', '').strip
      end

      raise Interstellar::DocumentNotFoundError, "API Error: #{@@name}: Document not found" if link_id.blank?

      browser.element(css: "##{link_id}").click
      url = browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/embed').attribute_value('src')

      ret = download_document(type, tracking_number, url)

      browser.element(xpath: '/html/body/div[1]/div[1]/div[2]/div[4]').click
      browser.element(xpath: '/html/body/div[12]/div[11]/div/button[1]').wait_until(&:present?).click
      browser.close

      ret
    end

    # Pickups

    def parse_pickup_response(
      delivery_from:,
      delivery_to:,
      dispatcher:,
      pickup_from:,
      pickup_to:,
      scac:,
      service:,
      shipment:
    )
      browser = Watir::Browser.new(*@options[:watir_args])
      browser.goto(build_url(:pickup))

      browser.text_field(name: 'userid').set(@options[:username])
      browser.text_field(name: 'password').set(@options[:password])
      browser.button(name: 'btnLogin').click

      if browser.html.include?('You are not enrolled in any application environments on this server')
        browser.close
        raise Interstellar::InvalidCredentialsError,
              'You are not enrolled in any application environments on this server'
      end

      if browser.html.include?('You already have the maximum permitted application sessions open')
        browser.close
        raise Interstellar::ResponseError, 'You already have the maximum permitted application sessions open'
      end

      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[2]/img').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[3]/ul[2]/li').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[3]/ul[2]/li[2]/span[2]').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div[1]/div[6]/div/table/tbody/tr/td[1]/table/tbody/tr/td[2]/div/span/img').wait_until(&:present?).click

      shipper_name = shipment.origin.contact.company_name.upcase.squish.strip
      new_customer = true

      browser.select_list(id: 'DPSC').wait_until(&:present?).click

      if browser.select_list(id: 'DPSC').options.to_a.map(&:text).include?(shipper_name)
        new_customer = false
        browser.option(text: shipper_name).click
      else
        browser.option(text: '<new>').click

        browser.text_field(name: 'SHPNAM').set(shipper_name.upcase)
        browser.text_field(name: 'SHPAD1').set(shipment.origin.address1.upcase)
        browser.text_field(name: 'SHPCTY').set(shipment.origin.city.upcase)
        browser.text_field(name: 'SHPSTA').set(shipment.origin.state.upcase[..1])
        browser.text_field(name: 'SHPZIP').set(shipment.origin.zip.gsub(/\s+/, '').upcase)
      end

      browser.text_field(name: 'DPADAT').set(pickup_from.to_date.strftime('%m/%d/%Y'))
      browser.text_field(name: 'DPATIM').set(pickup_from.strftime('%H:%M'))
      browser.text_field(name: 'DPCTIM').set(pickup_to.strftime('%H:%M'))

      total_weight = shipment.packages.map { |p| p.pounds(:total) }.sum.ceil

      browser.text_field(name: 'DSTWT_1').set(total_weight)
      browser.text_field(name: 'DSDZIP_1').set(shipment.destination.zip.gsub(/\s+/, '').upcase)
      browser.text_field(name: 'DSTPC_1').set(shipment.packages.map(&:quantity).sum)
      browser.text_field(name: 'DSPLT_1').set(shipment.packages.map(&:quantity).sum)

      browser.checkbox(name: 'DSHAZ_1').check if shipment.packages.map(&:hazmat?).include?(true)

      browser.checkbox(name: 'DSLIFT_1').check if shipment.accessorials.include?(:liftgate_pickup)

      browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div/div[2]/div/div[1]/div/button[2]/span').click

      if new_customer
        browser.radio(id: 'CCS', value: 'NEW').wait_until(&:present?).select
        browser.element(xpath: '/html/body/div[3]/div[2]/div[2]/div/div[1]/div/button[1]').click
      end

      browser.text_field(name: 'DPADAT').wait_until(&:present?).set(pickup_from.to_date.strftime('%m/%d/%Y'))
      browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/form[1]/div/div[2]/div/div/table/tbody/tr/td[2]/a/img').click

      html = browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div[1]/div[3]/div[3]/div/table').wait_until(&:present?).html
      html = Nokogiri::HTML.parse(html)

      pickup_number = nil

      html.css('tr').each do |tr|
        next unless tr.text.include?(shipper_name) && tr.text.include?(total_weight)

        pickup_number = tr.css('td')[1].text
      end

      browser.element(xpath: '/html/body/div[1]/div[1]/div[2]/div[4]').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[10]/div[11]/div/button[1]').wait_until(&:present?).click
      browser.close

      pickup_response = PickupResponse.new(request: nil, response: html)

      if pickup_number.blank?
        pickup_response.error = Interstellar::ResponseError.new('Unknown response')
        return pickup_response
      end

      pickup_response.pickup_number = pickup_number
      pickup_response
    end

    # Rates

    def build_rate_request(shipment:)
      accessorials = []

      unless shipment.accessorials.blank?
        serviceable_accessorials?(shipment.accessorials)
        shipment.accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << { code: @conf.dig(:accessorials, :mappable)[a] }
          end
        end
      end

      accessorials = accessorials.uniq.to_a

      items = []
      shipment.packages.each do |package|
        items << {
          _class: package.freight_class,
          description: (package.description || 'Freight')[..8].upcase,
          haz: (package.hazmat? ? 'Y' : ''),
          pallets: (package.packaging.pallet? ? package.quantity : 0),
          pieces: package.quantity,
          weight: package.pounds(:total).ceil
        }
      end

      request = {
        'arg0' => {
          securityinfo: build_soap_header,
          quote: {
            iam: 'D', # S for shipper, C for consignee, D for third party
            shipper: {
              city: shipment.origin.city.upcase,
              state: shipment.origin.state.upcase,
              zip: shipment.origin.zip.gsub(/\s+/, '').upcase
            },
            consignee: {
              city: shipment.destination.city.upcase,
              state: shipment.destination.state.upcase,
              zip: shipment.destination.zip.gsub(/\s+/, '').upcase
            },
            accessorialcount: shipment.accessorials.size,
            accessorial: shipment.accessorials.blank? ? [] : accessorials,
            ppdcol: 'P', # Prepaid
            itemcount: shipment.packages.size,
            item: items
          }
        }
      }

      save_request(request)
      request
    end

    def rate_item_description(rate_item)
      description = rate_item[:description] || ''
      description = description.gsub('-', '')
      description = description.squish
      description = description.sub('disc.on', 'discount on')
      description = description.capitalize
      description = description.sub('zip code', 'ZIP code')
      description = description.sub('Zip code', 'ZIP code')
    end

    def parse_rate_response(shipment:, response:)
      success = true
      message = ''

      raise Interstellar::ResponseError, 'API Error: Unknown response' if response.blank?

      unless response.dig(:getquote_response, :return, :rating, :errorcode).blank?
        error_code = response.dig(:getquote_response, :return, :rating, :errorcode)

        case error_code
        when 'NOSVC'
          raise Interstellar::UnserviceableError, 'Origin or destination has no service available'
        when 'BADCONZIP'
          raise Interstellar::UnserviceableError, 'Invalid destination ZIP code'
        end

        raise Interstellar::ResponseError, "API Error: #{error_code}"
      end

      total_cents = response.dig(:getquote_response, :return, :rating, :amount)

      raise Interstellar::ResponseError, 'API Error: Cost is empty' if total_cents.blank?

      total_cents = (total_cents.to_f * 100).to_i

      freight_price = nil
      prices = []

      rate_items = response.dig(:getquote_response, :return, :rateitem)

      # Confusing API sometimes returns lines of freight with high costs and then later includes includes lines that
      # override the high cost without adding a discount, etc
      rate_items.each do |rate_item|
        next if ['Sub Total', 'GrandTotal'].include?(rate_item[:acccode])

        # Exclude lines that are just the packages repeated back to us
        next unless rate_item[:pallets] == '0' && rate_item[:pieces] == '0'

        cents = (rate_item[:amount].to_f * 100).to_i
        description = rate_item_description(rate_item)

        prices << Price.new(blame: :api, cents:, description:)
      end

      # Since we expected the low-cost overriding lines earlier, we need to handle situations where those lines do not
      # appear
      if prices.sum(&:cents) < total_cents
        prices = [
          Price.new(
            blame: :api,
            cents: total_cents - prices.sum(&:cents),
            description: 'Freight'
          )
        ] + prices
      end

      shipment.packages.each do |package|
        cents = overlength_fee(@options[:tariff], package)
        next unless cents.positive?

        prices << Price.new(
          blame: :tariff,
          cents:,
          description: 'Overlength fee'
        )
      end

      transit_days = response.dig(
        :getquote_response,
        :return,
        :service,
        :days
      ).to_i

      # Calculate real transit time based on information we have about the destination service days
      %i[mon tue wed thu fri].each do |weekday|
        transit_days += 1 if response.dig(:getquote_response, :return, :service, :destination, weekday) == 'N'
      end

      estimate_reference = response.dig(
        :getquote_response,
        :return,
        :rating,
        :quotenumber
      )

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

    # Tracking

    def build_tracking_request(tracking_number)
      request = {
        'arg0' => {
          securityinfo: build_soap_header,
          pronumber: tracking_number
        }
      }

      save_request(request)
      request
    end

    def parse_location(code)
      country = ActiveUtils::Country.find('USA')
      return Location.new(country:) unless code

      location = @conf.dig(:events, :locations, code.to_sym)

      if location
        Location.new(
          city: location[:city],
          province: location[:state],
          country:
        )
      else
        Location.new(city: code, country:)
      end
    end

    def parse_tracking_response(response)
      tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)

      unless response.dig(:tracktrace_response, :return, :currentstatus, :errorcode).blank?
        tracking_response.error = ShipmentNotFoundError.new
        return tracking_response
      end

      receiver_location = Location.new(
        city: response.dig(:tracktrace_response, :return, :currentstatus, :consignee, :city).titleize,
        province: response.dig(:tracktrace_response, :return, :currentstatus, :consignee, :state).upcase,
        country: ActiveUtils::Country.find('USA')
      )

      shipper_location = Location.new(
        city: response.dig(:tracktrace_response, :return, :currentstatus, :shipper, :city).titleize,
        province: response.dig(:tracktrace_response, :return, :currentstatus, :shipper, :state).upcase,
        country: ActiveUtils::Country.find('USA')
      )

      actual_delivery_date = response.dig(:tracktrace_response, :return, :currentstatus, :deliverydate)
      unless actual_delivery_date.blank?
        comment = response.dig(:tracktrace_response, :return, :currentstatus, :status).downcase
        if comment.starts_with?('delivered')
          api_date = comment.downcase.split('signed')[0].split('on')[1].strip.sub('at ', '')
          actual_delivery_date = parse_api_date(api_date)
        end
      end

      shipment_events = []
      status = nil

      api_date = response.dig(:tracktrace_response, :return, :currentstatus, :shipdate)
      ship_time = parse_api_date(api_date)

      # Leave this open for modification later
      picked_up_event = ShipmentEvent.new(location: shipper_location, date_time: ship_time, type_code: :picked_up)

      api_date = response.dig(:tracktrace_response, :return, :currentstatus, :estdeliverydate)
      scheduled_delivery_date = parse_api_date(api_date)

      tracking_number = response.dig(:tracktrace_response, :return, :pronumber)

      api_events = response.dig(:tracktrace_response, :return, :history)
      api_events = [api_events] if api_events.is_a?(Hash)

      api_events.each_with_index do |api_event, index|
        event = nil
        @conf.dig(:events, :types).each do |key, val|
          if api_event[:description].downcase.include? val
            event = key
            break
          end
        end
        next if event.blank?

        location = if api_event[:location].blank?
                     case event
                     when :picked_up, :pickup_information_sent_to_carrier
                       shipper_location
                     when :delivered, :out_for_delivery
                       receiver_location
                     end
                   else
                     parse_location(api_event[:location])
                   end

        api_date_time = "#{api_event[:date]} #{api_event[:time]}"
        date_time = parse_api_date_time(api_date_time, location)

        case event
        when :arrived_at_terminal
          # Duplicate event occurs without location data from API
          break if api_event[:location].blank?
        when :delivered
          actual_delivery_date = date_time
        when :out_for_delivery
          # Do not consider out for delivery when out for delivery and interlined dates match
          next_api_event = api_events[index + 1]

          break if next_api_event.blank?

          if next_api_event[:description].include?('INTERLINE') && next_api_event[:date] == api_event[:date]
            shipment_events << ShipmentEvent.new(date_time:, location:, type_code: :departed)
            next
          end
        when :pickup_information_sent_to_carrier
          # Pickup event appears after carrier information sent, let's fix that
          picked_up_event.date_time = date_time.dup
        end

        shipment_events << ShipmentEvent.new(date_time:, location:, type_code: event)
      end

      shipment_events << picked_up_event

      shipment_events = shipment_events.sort_by do |shipment_event|
        d = shipment_event.date_time
        d&.local_date_time || d.date_time_with_zone&.to_fs(:db) || d.local_date&.to_fs(:db)
      end

      status = shipment_events.last&.type_code

      # Workarounds for false status on certain events when timestamps are in wrong order
      status = :out_for_delivery if shipment_events.select do |shipment_event|
                                      shipment_event.type_code == :out_for_delivery
                                    end.any?
      status = :delivered if shipment_events.select { |shipment_event| shipment_event.type_code == :delivered }.any?

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
