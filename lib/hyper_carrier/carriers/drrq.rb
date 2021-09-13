# frozen_string_literal: true

module HyperCarrier
  class DRRQ < HyperCarrier::Carrier
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

    def build_headers(action, options = {})
      options = @options.merge(options)

      case action
      when :quote
        JSON_HEADERS.merge(
          {
            'UserName' => options[:username],
            'ApiKey' => options[:password]
          }
        )
      else
        {}
      end
    end

    def build_url(action)
      "#{@conf.dig(:api, :use_ssl, action) ? 'https' : 'http'}://#{@conf.dig(:api, :domains, action)}#{@conf.dig(:api, :endpoints, action)}"
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

      JSON.parse(response.body) if response&.body
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl, action) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
    end

    # Documents

    def parse_document_response(type, tracking_number, url, options = {})
      options = @options.merge(options)

      raise HyperCarrier::DocumentNotFound, "API Error: #{self.class.name}: Document not found" if url.blank?

      path = if options[:path].blank?
               File.join(Dir.tmpdir, "#{self.class.name} #{tracking_number} #{type.to_s.upcase}.pdf")
             else
               options[:path]
             end
      file = File.new(path, 'w')

      File.open(file.path, 'wb') do |file|
        URI.parse(url).open do |input|
          file.write(input.read)
        end
      rescue OpenURI::HTTPError
        raise HyperCarrier::DocumentNotFound, "API Error: #{self.class.name}: Document not found"
      end

      unless url.end_with?('.pdf')
        file = Magick::ImageList.new(file.path)
        file.write(path)
      end

      File.exist?(path) ? path : false
    end

    def parse_pod_response(tracking_number, options = {})
      options = @options.merge(options)
      browser = Watir::Browser.new(:chrome, headless: !@debug)
      browser.goto(build_url(:pod))

      browser.text_field(name: 'UserId').set(options[:username])
      browser.text_field(name: 'Password').set(options[:password])
      browser.button(name: 'submitbutton').click

      browser
        .element(xpath: '//*[@id="__AppFrameBaseTable"]/tbody/tr[2]/td/div[4]')
        .click

      browser.iframes(src: '../mainframe/MainFrame.jsp?bRedirect=true')
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
        raise HyperCarrier::DocumentNotFound, "API Error: #{self.class.name}: Document not found"
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

      parse_document_response(:pod, tracking_number, url, options)
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
        url: build_url(:quote),
        headers: build_headers(:quote, options),
        method: @conf.dig(:api, :methods, :quote),
        body: body
      }

      save_request(request)
      request
    end

    def parse_rate_response(origin, destination, response)
      success = true
      message = ''
      rate_estimates = []

      if !response
        success = false
        message = 'API Error: Unknown response'
      else
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
end
