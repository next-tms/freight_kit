# frozen_string_literal: true

module Interstellar
  class BTVP < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Best Overnite Express'
    @@scac = 'BTVP'

    def maximum_height
      Measured::Length.new(95, :inches)
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

    # Pickups

    def create_pickup(
      accessorials:,
      customer_reference:,
      delivery_from:,
      delivery_to:,
      destination:,
      dispatcher_email:,
      dispatcher_name:,
      dispatcher_phone:,
      origin:,
      packages:,
      pickup_from:,
      pickup_to:,
      receiver_contact_name:,
      receiver_name:,
      receiver_phone:,
      receiver_reference:,
      scac:,
      service:,
      shipper_contact_name:,
      shipper_name:,
      shipper_phone:,
      shipper_reference:
    )
      parse_pickup_response(
        accessorials: accessorials,
        customer_reference: customer_reference,
        delivery_from: delivery_from,
        delivery_to: delivery_to,
        destination: destination,
        dispatcher_email: dispatcher_email,
        dispatcher_name: dispatcher_name,
        dispatcher_phone: dispatcher_phone,
        origin: origin,
        packages: packages,
        pickup_from: pickup_from,
        pickup_to: pickup_to,
        receiver_contact_name: receiver_contact_name,
        receiver_name: receiver_name,
        receiver_phone: receiver_phone,
        receiver_reference: receiver_reference,
        scac: scac,
        service: service,
        shipper_contact_name: shipper_contact_name,
        shipper_name: shipper_name,
        shipper_phone: shipper_phone,
        shipper_reference: shipper_reference
      )
    end

    def create_pickup_implemented?
      true
    end

    # Rates

    def find_rates(origin, destination, packages, options = {})
      options = @options.merge(options)

      origin = Location.from(origin)
      destination = Location.from(destination)
      packages = Array(packages)

      validate_packages(packages, options[:tariff])

      request = build_rate_request(origin, destination, packages, options)
      parse_rate_response(origin, destination, packages, commit(:rates, request))
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

    def parse_date(date)
      date ? Date.strptime(date, '%m/%d/%Y').to_s(:db) : nil
    end

    def parse_datetime(datetime)
      return nil unless datetime

      if datetime.include?('-')
        DateTime.strptime(datetime, '%Y-%m-%d %H:%M').to_s(:db)
      else
        DateTime.strptime(datetime, '%m/%d/%Y %H:%M').to_s(:db)
      end
    end

    def build_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domain)}:#{@conf.dig(:api, :ports, action)}#{@conf.dig(:api, :endpoints, action)}"
    end

    def strip_date(str)
      str ? str.split(/[A|P]M /)[1] : nil
    end

    # Documents

    def download_document(type, tracking_number, url, options = {})
      options = @options.merge(options)
      path = if options[:path].blank?
               File.join(Dir.tmpdir,
                         "#{@@name} #{tracking_number} #{type.to_s.upcase}.pdf")
             else
               options[:path]
             end
      file = File.new(path, 'w')

      File.open(file.path, 'wb') do |file|
        URI.parse(url).open do |input|
          file.write(input.read)
        end
      rescue OpenURI::HTTPError
        raise Interstellar::DocumentNotFoundError, "API Error: #{@@name}: Document not found"
      end

      File.exist?(path) ? path : false
    end

    def parse_document_response(type, tracking_number, options = {})
      options = @options.merge(options)
      browser = Watir::Browser.new(*options[:watir_args])
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

      ret = download_document(type, tracking_number, url, options)

      browser.element(xpath: '/html/body/div[1]/div[1]/div[2]/div[4]').click
      browser.element(xpath: '/html/body/div[12]/div[11]/div/button[1]').wait_until(&:present?).click
      browser.close

      ret
    end

    # Pickups

    def parse_pickup_response(
      accessorials: accessorials,
      customer_reference: customer_reference,
      delivery_from: delivery_from,
      delivery_to: delivery_to,
      destination: destination,
      dispatcher_email: dispatcher_email,
      dispatcher_name: dispatcher_name,
      dispatcher_phone: dispatcher_phone,
      origin: origin,
      packages: packages,
      pickup_from: pickup_from,
      pickup_to: pickup_to,
      receiver_contact_name: receiver_contact_name,
      receiver_name: receiver_name,
      receiver_phone: receiver_phone,
      receiver_reference: receiver_reference,
      scac: scac,
      service: service,
      shipper_contact_name: shipper_contact_name,
      shipper_name: shipper_name,
      shipper_phone: shipper_phone,
      shipper_reference: shipper_reference
    )
      options = @options
      browser = Watir::Browser.new(*options[:watir_args])
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

      shipper_name = shipper_name.upcase.squish.strip
      new_customer = true

      browser.select_list(id: 'DPSC').wait_until(&:present?).click

      if browser.select_list(id: 'DPSC').options.to_a.map(&:text).include?(shipper_name)
        new_customer = false
        browser.option(text: shipper_name).click
      else
        browser.option(text: '<new>').click

        browser.text_field(name: 'SHPNAM').set(shipper_name.upcase)
        browser.text_field(name: 'SHPAD1').set(origin.to_hash[:address1].upcase)
        browser.text_field(name: 'SHPCTY').set(origin.to_hash[:city].upcase)
        browser.text_field(name: 'SHPSTA').set(origin.to_hash[:province].upcase[..1])
        browser.text_field(name: 'SHPZIP').set(origin.to_hash[:postal_code])
      end

      browser.text_field(name: 'DPADAT').set(pickup_from.to_date.strftime('%m/%d/%Y'))
      browser.text_field(name: 'DPATIM').set(pickup_from.strftime('%H:%M'))
      browser.text_field(name: 'DPCTIM').set(pickup_to.strftime('%H:%M'))

      total_weight = packages.map { |p| p.pounds(:total) }.sum.ceil

      browser.text_field(name: 'DSTWT_1').set(total_weight)
      browser.text_field(name: 'DSDZIP_1').set(destination.to_hash[:postal_code])
      browser.text_field(name: 'DSTPC_1').set(packages.map { |p| p.quantity }.sum)
      browser.text_field(name: 'DSPLT_1').set(packages.map { |p| p.quantity }.sum)

      if packages.map(&:hazmat?).include?(true)
        browser.checkbox(name: 'DSHAZ_1').check
      end

      if accessorials.include?(:liftgate_pickup)
        browser.checkbox(name: 'DSLIFT_1').check
      end

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

      return pickup_number
    end

    # Rates

    def build_rate_request(origin, destination, packages, options = {})
      options = @options.merge(options)

      accessorials = []

      unless options[:accessorials].blank?
        serviceable_accessorials?(options[:accessorials])
        options[:accessorials].each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << { code: @conf.dig(:accessorials, :mappable)[a] }
          end
        end
      end

      accessorials = accessorials.uniq.to_a

      items = []
      packages.each do |package|
        items << {
          _class: package.freight_class,
          description: (packages.first.description || 'Freight')[..8].upcase,
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
            iam: options[:iam].blank? ? 'D' : options[:iam], # S for shipper, C for consignee, D for third party
            shipper: {
              city: origin.to_hash[:city].to_s.upcase,
              state: origin.to_hash[:province].to_s.upcase,
              zip: origin.to_hash[:postal_code].to_s.upcase
            },
            consignee: {
              city: destination.to_hash[:city].to_s.upcase,
              state: destination.to_hash[:province].to_s.upcase,
              zip: destination.to_hash[:postal_code].to_s.upcase
            },
            accessorialcount: accessorials.size,
            accessorial: accessorials.blank? ? [] : accessorials,
            ppdcol: options[:payment_type].blank? ? 'P' : options[:payment_type].blank?, # Prepaid
            itemcount: packages.size,
            item: items
          }
        }
      }

      save_request(request)
      request
    end

    def parse_rate_response(origin, destination, packages, response)
      success = true
      message = ''

      if !response
        success = false
        message = 'API Error: Unknown response'
      elsif !response.dig(:getquote_response, :return, :rating, :errorcode).blank?
        error_code = response.dig(:getquote_response, :return, :rating, :errorcode)

        raise Interstellar::UnserviceableError if error_code == 'NOSVC'

        success = false
        message = error_code
      else
        cost = (response.dig(:getquote_response, :return, :rating, :amount).to_f * 100).to_i

        packages.each do |package|
          cost += overlength_fee(@options[:tariff], package)
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

        if cost
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

      RateResponse.new(
        success,
        message,
        response,
        rates: rate_estimates,
        response: response,
        request: last_request
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
      return Location.new(country: country) unless code

      location = @conf.dig(:events, :locations, code.to_sym)

      if location
        Location.new(
          city: location[:city],
          state: location[:state],
          province: location[:province],
          country: country
        )
      else
        Location.new(
          city: code,
          province: nil,
          state: nil,
          country: country
        )
      end
    end

    def parse_tracking_response(response)
      raise Interstellar::ShipmentNotFoundError unless response.dig(:tracktrace_response, :return, :currentstatus,
                                                                    :errorcode).blank?

      receiver_address = Location.new(
        city: response.dig(:tracktrace_response, :return, :currentstatus, :consignee, :city).titleize,
        province: response.dig(:tracktrace_response, :return, :currentstatus, :consignee, :state).upcase,
        state: response.dig(:tracktrace_response, :return, :currentstatus, :consignee, :state).upcase,
        country: ActiveUtils::Country.find('USA')
      )

      shipper_address = Location.new(
        city: response.dig(:tracktrace_response, :return, :currentstatus, :shipper, :city).titleize,
        province: response.dig(:tracktrace_response, :return, :currentstatus, :shipper, :state).upcase,
        state: response.dig(:tracktrace_response, :return, :currentstatus, :shipper, :state).upcase,
        country: ActiveUtils::Country.find('USA')
      )

      actual_delivery_date = response.dig(:tracktrace_response, :return, :currentstatus, :deliverydate)
      unless actual_delivery_date.blank?
        comment = response.dig(:tracktrace_response, :return, :currentstatus, :status).downcase
        if comment.starts_with?('delivered')
          actual_delivery_date = parse_date(comment.downcase.split('signed')[0].split('on')[1].strip.sub('at ', ''))
        end
      end

      ship_time = parse_date(response.dig(:tracktrace_response, :return, :currentstatus, :shipdate))
      scheduled_delivery_date = parse_date(response.dig(:tracktrace_response, :return, :currentstatus,
                                                        :estdeliverydate))
      tracking_number = response.dig(:tracktrace_response, :return, :pronumber)

      shipment_events = []
      status = nil

      api_events = response.dig(:tracktrace_response, :return, :history)
      api_events = [api_events] if api_events.is_a?(Hash)

      api_events.each do |api_event|
        event = nil
        @conf.dig(:events, :types).each do |key, val|
          if api_event[:description].downcase.include? val
            event = key
            break
          end
        end
        next if event.blank?

        datetime_without_time_zone = parse_datetime("#{api_event[:date]} #{api_event[:time]}")

        location = parse_location(api_event[:location])
        location = shipper_address if location.state.blank? && %i[picked_up
                                                                  pickup_information_sent_to_carrier].include?(event)
        location = receiver_address if location.state.blank? && %i[delivered out_for_delivery].include?(event)

        status = event

        shipment_events << ShipmentEvent.new(event, datetime_without_time_zone, location)
      end

      shipment_events = shipment_events.sort_by(&:time)

      # Workaround for false status on certain events when timestamps are in wrong order
      if !status == :out_for_delivery
        out_for_delivery_event = shipment_events.select { |shipment_event| shipment_event.status == :out_for_delivery }
        status = :out_for_delivery unless out_for_delivery_event.blank?
      end
      if !status == :delivered
        delivery_event = shipment_events.select { |shipment_event| shipment_event.status == :delivered }
        status = :delivered unless delivery_event.blank?
      end

      status = shipment_events.last&.status if status.blank?

      TrackingResponse.new(
        true,
        shipment_events.last&.status,
        response,
        carrier: "#{@@scac}, #{@@name}",
        xml: response,
        response: response,
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
