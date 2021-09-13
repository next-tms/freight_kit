# frozen_string_literal: true

module HyperCarrier
  class BTVP < HyperCarrier::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Best Overnite Express'
    @@scac = 'BTVP'

    def requirements
      %i[username password]
    end

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

      raise "Error: #{@@name}: Pallet count 5+ unsupported" if packages.size >= 5
      if packages.sum { |p| p.pounds } > 10_000
        raise "Error: #{@@name}: Weight > 10,000 lbs unsupported"
      end

      packages.each do |package|
        if package.height(:inches) > 95
          raise "Error: #{@@name}: Height > 95 inches unsupported"
        end
      end

      request = build_rate_request(origin, destination, packages, options)
      parse_rate_response(origin, destination, packages, commit(:rates, request))
    end

    # Tracking
    def find_tracking_info(tracking_number, options = {})
      options = @options.merge(options)
      request = build_tracking_request(tracking_number)
      parse_tracking_response(commit(:track, request))
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
      path = options[:path].blank? ? File.join(Dir.tmpdir, "#{@@name} #{tracking_number} #{type.to_s.upcase}.pdf") : options[:path]
      file = File.new(path, 'w')

      File.open(file.path, 'wb') do |file|
        URI.parse(url).open do |input|
          file.write(input.read)
        end
      rescue OpenURI::HTTPError
        raise HyperCarrier::DocumentNotFound, "API Error: #{@@name}: Document not found"
      end

      File.exist?(path) ? path : false
    end

    def parse_document_response(type, tracking_number, options = {})
      options = @options.merge(options)
      browser = Watir::Browser.new(:chrome, headless: !@debug)
      browser.goto(build_url(:pod))

      browser.text_field(name: 'userid').set(@options[:username])
      browser.text_field(name: 'password').set(@options[:password])
      browser.button(name: 'btnLogin').click

      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[2]/img').click
      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[3]/ul[2]/li').click
      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[3]/ul[2]/li[6]/span[2]').click
      browser.select_list(name: 'TATIWT').select('S')

      browser.textarea(name: 'TATFB').set(tracking_number)
      browser.button(xpath: '/html/body/div[1]/div[3]/div[3]/div/div[1]/div/button[2]').click

      browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div[1]/div[4]/div[3]/div/table/tbody/tr[2]/td[2]').double_click

      html = browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div/div/form/div[4]/div[2]/div/div/table').inner_html
      html = Nokogiri::HTML.parse(html)

      url = nil
      html.css('tr').each do |tr|
        next unless tr.text.downcase.include?(@conf.dig(:documents, :types, type).downcase)

        link_id = tr.css('td')[1].css('a').to_html.split('id=')[1].split('onfocus')[0].gsub('"', '').strip
        browser.element(css: "##{link_id}").click
        url = browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/embed').attribute_value('src')
      end

      browser.close

      raise HyperCarrier::DocumentNotFound, "API Error: #{@@name}: Document not found" if url.blank?

      download_document(type, tracking_number, url, options)
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
            item: packages.inject([]) do |arr, package|
              arr << {
                _class: package.freight_class,
                description: 'Freight'.upcase, # Required
                haz: '', # Y if yes
                pallets: 1,
                pieces: 1,
                weight: package.pounds.ceil
              }
            end
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
      else
        if !response.dig(:getquote_response, :return, :rating, :errorcode).blank?
          success = false
          message = response.dig(:getquote_response, :return, :rating, :errorcode)
        else
          cost = (response.dig(:getquote_response, :return, :rating, :amount).to_f * 100).to_i

          longest_dimension = packages.inject([]) { |_arr, p| [p.length(:in), p.width(:in)] }.max.ceil
          if !@options[:tariff].blank?
            if longest_dimension >= 168
              cost += @options[:tariff].dig('overlength_fees').dig('over_14_ft')
            elsif longest_dimension >= 144 && longest_dimension < 168
              cost += @options[:tariff].dig('overlength_fees').dig('12_through_14_ft')
            elsif longest_dimension >= 120 && longest_dimension < 144
              cost += @options[:tariff].dig('overlength_fees').dig('10_through_12_ft')
            elsif longest_dimension >= 96 && longest_dimension < 120
              cost += @options[:tariff].dig('overlength_fees').dig('8_through_10_ft')
            end
          elsif longest_dimension >= 96
            warn 'API Warning: Overlength fees not applied because `tariff` is empty!'
          end

          transit_days = response.dig(
            :getquote_response,
            :return,
            :service,
            :days
          ).to_i

          # Calculate real transit time based on information we have about the destination service days
          %i[mon tue wed thu fri].each do |weekday|
            days += 1 if response.dig(:getquote_response, :return, :service, :destination, weekday) == 'N'
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
      case code
      when '31'
        Location.new(
          city: 'Las Vegas',
          province: 'NV',
          state: 'NV',
          country: ActiveUtils::Country.find('USA')
        )
      when '50'
        Location.new(
          city: 'Phoenix',
          province: 'AZ',
          state: 'AZ',
          country: ActiveUtils::Country.find('USA')
        )
      when '62'
        Location.new(
          city: 'Denver',
          province: 'CO',
          state: 'CO',
          country: ActiveUtils::Country.find('USA')
        )
      when 'BEN'
        Location.new(
          city: 'Benicia',
          province: 'CA',
          state: 'CA',
          country: ActiveUtils::Country.find('USA')
        )
      when 'DAL'
        Location.new(
          city: 'Dallas',
          province: 'TX',
          state: 'TX',
          country: ActiveUtils::Country.find('USA')
        )
      when 'FRES'
        Location.new(
          city: 'Fresno',
          province: 'CA',
          state: 'CA',
          country: ActiveUtils::Country.find('USA')
        )
      when 'DENT'
        Location.new(
          city: 'Kent',
          province: 'WA',
          state: 'WA',
          country: ActiveUtils::Country.find('USA')
        )
      when 'LA'
        Location.new(
          city: 'Los Angeles',
          province: 'CA',
          state: 'CA',
          country: ActiveUtils::Country.find('USA')
        )
      when 'PDX'
        Location.new(
          city: 'Portland',
          province: 'OR',
          state: 'OR',
          country: ActiveUtils::Country.find('USA')
        )
      when 'SAC'
        Location.new(
          city: 'Sacramento',
          province: 'CA',
          state: 'CA',
          country: ActiveUtils::Country.find('USA')
        )
      when 'SJ'
        Location.new(
          city: 'San Jose',
          province: 'CA',
          state: 'CA',
          country: ActiveUtils::Country.find('USA')
        )
      else
        Location.new(
          city: code,
          province: nil,
          state: nil,
          country: ActiveUtils::Country.find('USA')
        )
      end
    end

    def parse_tracking_response(response)
      unless response.dig(:tracktrace_response, :return, :currentstatus, :errorcode).blank?
        status = response.dig(:tracktrace_response, :return, :currentstatus, :errorcode)
        return TrackingResponse.new(false, status, response, carrier: "#{@@scac}, #{@@name}", xml: response, response: response, request: last_request)
      end

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
      scheduled_delivery_date = parse_date(response.dig(:tracktrace_response, :return, :currentstatus, :estdeliverydate))
      tracking_number = response.dig(:tracktrace_response, :return, :pronumber)

      shipment_events = []
      status = nil
      response.dig(:tracktrace_response, :return, :history).each do |api_event|
        event = nil
        @conf.dig(:events, :types).each do |key, val|
          if api_event.dig(:description).downcase.include? val
            event = key
            break
          end
        end
        next if event.blank?

        datetime_without_time_zone = parse_datetime("#{api_event.dig(:date)} #{api_event.dig(:time)}")

        location = parse_location(api_event.dig(:location))
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
