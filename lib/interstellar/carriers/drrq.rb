# frozen_string_literal: true

module Interstellar
  class DRRQ < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    JSON_HEADERS = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'charset': 'utf-8'
    }.freeze

    cattr_reader :name, :scac
    @@name = 'TForce Worldwide'
    @@scac = 'DRRQ'

    def available_services
      nil
    end

    def requirements
      %i[username password]
    end

    # Documents

    def find_bol(tracking_number, options = {})
      options = @options.merge(options)
      request = build_document_request(:bol, tracking_number, options)
      parse_bol_response(commit(request), :bol, tracking_number, options)
    end

    def find_pod(tracking_number, options = {})
      options = @options.merge(options)
      parse_pod_response(tracking_number, options)
    end

    # Rates

    def find_rates(origin, destination, packages, options = {})
      options = @options.merge(options)
      origin = Location.from(origin)
      destination = Location.from(destination)
      packages = Array(packages)

      request = build_rate_request(origin, destination, packages, options)
      parse_rate_response(origin, destination, commit(request))
    end

    # Tracking

    protected

    def build_headers(_action, options = {})
      options = @options.merge(options)

      JSON_HEADERS.merge(
        {
          'UserName' => options[:username],
          'ApiKey' => options[:password]
        }
      )
    end

    def commit(request)
      url = request[:url]
      headers = request[:headers]
      method = request[:method]
      body = request[:body]

      response = case method
                 when :post
                   HTTParty.post(url, headers: headers, body: body)
                 else
                   HTTParty.get(url, headers: headers)
                 end
    end

    def parse_response(response)
      case response.code
      when 400
        raise Interstellar::InvalidCredentialsError
      end

      raise Interstellar::ResponseError if response.code != 200

      response = begin
                   JSON.parse(response.body)
                 rescue JSON::ParserError => e
                   raise Interstellar::ResponseError
                 end

      response
    end

    def request_url(action)
      url = "#{@conf.dig(:api, :use_ssl, action) ? 'https' : 'http'}://#{@conf.dig(:api, :domains, action)}#{@conf.dig(:api, :endpoints, action)}"
      url
    end

    # Documents

    def build_document_request(type, tracking_number, options = {})
      request = {
        url: request_url(type).sub('%TRACKING_NUMBER%', tracking_number),
        method: @conf.dig(:api, :methods, type)
      }

      request[:headers] = build_headers(type, options) if type == :bol

      save_request(request)
      request
    end

    def parse_bol_response(response, type, tracking_number, options = {})
      options = @options.merge(options)
      response = parse_response(response)

      file_bytes = response.dig('FileBytes')
      return Interstellar::DocumentNotFound if file_bytes.blank?

      data = Base64.decode64(file_bytes)
      path = if options[:path].blank?
               File.join(Dir.tmpdir, "#{@@name} #{tracking_number} #{type.to_s.upcase}.pdf")
             else
               options[:path]
             end
      
      File.open(path, 'wb') {
        |f| f.write(data)
      }

      path
    end

    def parse_pod_response(tracking_number, options = {})
      options = @options.merge(options)

      request = build_document_request(:pod, tracking_number, options)
      browser = Watir::Browser.new(*options[:watir_args])
      browser.goto(request[:url])

      credentials = {
        username: options[:website_username] || options[:username],
        password: options[:website_password] || options[:password]
      }

      begin
        browser.text_field(name: 'UserId').set(credentials[:username])
        browser.text_field(name: 'Password').set(credentials[:password])
        browser.button(name: 'submitbutton').click
      rescue Selenium::WebDriver::Error::UnexpectedAlertOpenError
        browser.close
        raise InvalidCredentialsError
      end

      logout_url = 'https://rrd.mercurygate.net/MercuryGate/login/urlRedirect.jsp?Logout=true'

      browser
        .element(xpath: '//*[@id="__AppFrameBaseTable"]/tbody/tr[2]/td/div[4]')
        .click

      browser.iframes(src: '../mainframe/MainFrame.jsp?bRedirect=true')
      browser.iframe(name: 'AppBody').frame(id: 'Header')
             .select(name: 'column')
             .select('Primary Reference')
      browser.iframe(name: 'AppBody').frame(id: 'Header')
             .select(name: 'condition')
             .select('=')
      browser.iframe(name: 'AppBody').frame(id: 'Header')
             .text_field(name: 'filter')
             .set(tracking_number)
      browser.iframe(name: 'AppBody').frame(id: 'Header').button(value: 'Find')
             .click

      begin
        browser.iframe(name: 'AppBody').frame(id: 'Detail')
               .iframe(id: 'transportsWin')
               .element(xpath: '/html/body/div/table/tbody/tr[2]/td[1]/span/a[2]')
               .click
      rescue StandardError
        # POD not yet available
        browser.close
        raise Interstellar::DocumentNotFound, "API Error: #{self.class.name}: Document not found"
      end

      browser.iframe(name: 'AppBody').frame(id: 'Detail')
             .element(xpath: '/html/body/div[1]/div/div/div[1]/div[1]/div[2]/div/a[5]')
             .click

      html = browser.iframe(name: 'AppBody').frame(id: 'Detail').iframes[1]
                    .element(xpath: '/html/body/table[3]')
                    .html
      html = Nokogiri::HTML(html)

      browser.close

      url = nil
      html.css('tr').each do |tr|
        tds = tr.css('td')
        next if tds.size <= 1 || tds.blank?

        text = tds[1].text
        next unless text&.include?('http')

        url = text if url.blank? || !url.include?('hubtran') # Prefer HubTran
      end

      if url.blank?
        raise Interstellar::DocumentNotFound, "API Error: #{self.class.name}: Document not found"
      end

      path = if options[:path].blank?
               File.join(Dir.tmpdir, "#{self.class.name} #{tracking_number} POD.pdf")
             else
               options[:path]
             end
      file = File.new(path, 'w')

      File.open(file.path, 'wb') do |file|
        URI.parse(url).open do |input|
          file.write(input.read)
        end
      rescue OpenURI::HTTPError
        raise Interstellar::DocumentNotFound, "API Error: #{self.class.name}: Document not found"
      end

      unless MimeMagic.by_magic(File.open(path)).type == 'application/pdf'
        file = Magick::ImageList.new(file.path)
        file.write(path)
      end

      File.exist?(path) ? path : false
    end

    # Rates

    def build_rate_request(origin, destination, packages, options = {})
      options = @options.merge(options)

      accessorials = []

      unless options[:accessorials].blank?
        serviceable_accessorials?(options[:accessorials])
        options[:accessorials].each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << { ServiceCode: @conf.dig(:accessorials, :mappable)[a] }
          end
        end
      end

      longest_dimension_ft = (packages.inject([]) { |_arr, p| [p.length(:in), p.width(:in)] }.max.ceil.to_f / 12).ceil.to_i
      if longest_dimension_ft >= 8 && longest_dimension_ft < 30
        accessorials << { ServiceCode: "OVL#{longest_dimension_ft}" }
      end

      accessorials = accessorials.uniq.to_a

      items = []
      packages.each do |package|
        items << {
          Name: 'Freight',
          FreightClass: package.freight_class.to_s,
          Weight: package.pounds.ceil.to_s,
          WeightUnits: 'lb',
          Width: package.width(:in).ceil,
          Length: package.length(:in).ceil,
          Height: package.height(:in).ceil,
          DimensionUnits: 'in',
          Quantity: 1,
          QuantityUnits: 'PLT' # Check this
        }
      end

      body = {
        Constraints: {
          ServiceFlags: accessorials
        },
        Items: items,
        PickupEvent: {
          Date: DateTime.now.strftime('%m/%d/%Y %I:%M:00 %p'),
          LocationCode: 'PLocationCode',
          City: origin.to_hash[:city].upcase,
          State: origin.to_hash[:province].upcase,
          Zip: origin.to_hash[:postal_code].upcase,
          Country: 'USA'
        },
        DropEvent: {
          Date: (DateTime.now + 5.days).strftime('%m/%d/%Y %I:%M:00 %p'),
          LocationCode: 'DLocationCode',
          City: destination.to_hash[:city].upcase,
          State: destination.to_hash[:province].upcase,
          Zip: destination.to_hash[:postal_code].upcase,
          Country: 'USA',
          MaxPriceSheet: 6,
          ShowInsurance: false
        }
      }.to_json

      request = {
        url: request_url(:quote),
        headers: build_headers(:quote, options),
        method: @conf.dig(:api, :methods, :quote),
        body: body
      }

      save_request(request)
      request
    end

    def parse_rate_response(origin, destination, response)
      response = parse_response(response)

      success = true
      message = ''
      rate_estimates = []

      response.each do |response_line|
        next if response_line.dig('Message') # Signifies error

        cost = response_line.dig('Total')
        if cost
          cost = (cost.to_f * 100).to_i
          service = response_line.dig('Charges').map { |charges| charges.dig('Description') }
          service = case service
                    when service.any?('Standard LTL Guarantee')
                      :guaranteed
                    when service.any?('Guaranteed LTL Service AM')
                      :guaranteed_am
                    when service.any?('Guaranteed LTL Service PM')
                      :guaranteed_pm
                    else
                      :standard
                    end
          transit_days = response_line.dig('ServiceDays').to_i
          rate_estimates << RateEstimate.new(
            origin,
            destination,
            { scac: response_line.dig('Scac'), name: response_line.dig('CarrierName') },
            service,
            transit_days: transit_days,
            estimate_reference: nil,
            total_cost: cost,
            total_price: cost,
            currency: 'USD',
            with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
          )
        else
          next
        end
      end

      RateResponse.new(
        success,
        message,
        { response: response },
        rates: rate_estimates,
        response: response,
        request: last_request
      )
    end

    # Tracking
  end

  private
end
