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

    def bol_requires_tracking_number?
      true
    end

    def find_bol(tracking_number, options = {})
      options = @options.merge(options)
      request = build_document_request(:bol, tracking_number, options)
      parse_bol_response(commit(request), :bol, tracking_number, options)
    end

    def find_bol_implemented?
      true
    end

    def find_pod(tracking_number, options = {})
      options = @options.merge(options)
      parse_pod_response(tracking_number, options)
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
      origin:,
      packages:,
      pickup_from:,
      pickup_to:,
      receiver_contact_name:,
      receiver_name:,
      receiver_phone:,
      scac:,
      service:,
      shipper_contact_name:,
      shipper_name:,
      shipper_phone:,
      shipper_reference:
    )
      request = build_pickup_request(
        accessorials: accessorials,
        customer_reference: customer_reference,
        delivery_from: delivery_from,
        delivery_to: delivery_to,
        destination: destination,
        origin: origin,
        packages: packages,
        pickup_from: pickup_from,
        pickup_to: pickup_to,
        receiver_contact_name: receiver_contact_name,
        receiver_name: receiver_name,
        receiver_phone: receiver_phone,
        scac: scac,
        service: service,
        shipper_contact_name: shipper_contact_name,
        shipper_name: shipper_name,
        shipper_phone: shipper_phone,
        shipper_reference: shipper_reference
      )

      parse_pickup_response(commit(request))
    end

    def create_pickup_implemented?
      true
    end

    def pickup_number_is_tracking_number?
      true
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

    def find_rates_implemented?
      true
    end

    # Tracking

    protected

    def build_accessorials(accessorials:, packages:)
      serviceable_accessorials?(accessorials)

      parsed_accessorials = []

      accessorials.each do |a|
        unless @conf.dig(:accessorials, :unserviceable).include?(a)
          parsed_accessorials << { ServiceCode: @conf.dig(:accessorials, :mappable)[a] }
        end
      end

      longest_dimension_ft = (packages.inject([]) do |_arr, p|
                                [p.length(:in), p.width(:in)]
                              end.max.ceil.to_f / 12).ceil.to_i
      if longest_dimension_ft >= 8 && longest_dimension_ft < 30
        parsed_accessorials << { ServiceCode: "OVL#{longest_dimension_ft}" }
      end

      parsed_accessorials.uniq.to_a
    end

    def build_headers(options = {})
      options = @options.merge(options)

      JSON_HEADERS.merge(
        {
          ApiKey: options[:password],
          UserName: options[:username]
        }
      )
    end

    def commit(request)
      url = request[:url]
      headers = request[:headers]
      method = request[:method]
      body = request[:body]

      case method
      when :post
        HTTParty.post(url, headers: headers, body: body)
      else
        HTTParty.get(url, headers: headers)
      end
    end

    def parse_response(response)
      case response.code
      when 401
        raise Interstellar::InvalidCredentialsError, "HTTP #{response.code}: #{response}"
      end

      raise Interstellar::ResponseError, "HTTP #{response.code}: #{response}" if response.code != 200

      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Interstellar::ResponseError
      end
    end

    def request_url(action)
      env = test_mode? ? :staging : :production
      "https://#{@conf.dig(:api, :domains, env, action)}/#{@conf.dig(:api, :endpoints, action)}"
    end

    # Documents

    def build_document_request(type, tracking_number, options = {})
      request = {
        url: request_url(type).sub('%TRACKING_NUMBER%', tracking_number),
        method: @conf.dig(:api, :methods, type)
      }

      request[:headers] = build_headers(options) if type == :bol

      save_request(request)
      request
    end

    def parse_bol_response(response, type, tracking_number, options = {})
      options = @options.merge(options)
      response = parse_response(response)

      file_bytes = response['FileBytes']
      return Interstellar::DocumentNotFoundError if file_bytes.blank?

      data = Base64.decode64(file_bytes)
      path = if options[:path].blank?
               File.join(Dir.tmpdir, "#{@@name} #{tracking_number} #{type.to_s.upcase}.pdf")
             else
               options[:path]
             end

      File.open(path, 'wb') do |f|
        f.write(data)
      end

      path
    end

    def parse_pod_response(tracking_number, options = {})
      options = @options.merge(options)

      request = build_document_request(:pod, tracking_number, options)
      browser = Watir::Browser.new(*options[:watir_args])
      browser.goto(request[:url])

      if browser.html.downcase.include?('unable to process request')
        browser.close
        raise ResponseError
      end

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
        raise Interstellar::DocumentNotFoundError, "API Error: #{self.class.name}: Document not found"
      end

      browser.iframe(name: 'AppBody').frame(id: 'Detail')
             .element(xpath: '/html/body/div[1]/div/div/div[1]/div[1]/div[2]/div/a[5]')
             .click

      html = browser.iframe(name: 'AppBody').frame(id: 'Detail').iframes[1]
                    .element(xpath: '/html/body/table[3]')
                    .html
      html = Nokogiri::HTML(html)

      browser.goto(logout_url)
      browser.close

      url = nil
      html.css('tr').each do |tr|
        tds = tr.css('td')
        next if tds.size <= 1 || tds.blank?

        text = tds[1].text
        next unless text&.include?('http')

        url = text if url.blank? || !url.include?('hubtran') # Prefer HubTran
      end

      raise Interstellar::DocumentNotFoundError, "API Error: #{self.class.name}: Document not found" if url.blank?

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
        raise Interstellar::DocumentNotFoundError, "API Error: #{self.class.name}: Document not found"
      end

      unless MimeMagic.by_magic(File.open(path)).type == 'application/pdf'
        file = Magick::ImageList.new(file.path)
        file.write(path)
      end

      File.exist?(path) ? path : false
    end

    # Pickups

    def build_pickup_request(
      accessorials:,
      customer_reference:,
      delivery_from:,
      delivery_to:,
      destination:,
      origin:,
      packages:,
      pickup_from:,
      pickup_to:,
      receiver_contact_name:,
      receiver_name:,
      receiver_phone:,
      scac:,
      service:,
      shipper_contact_name:,
      shipper_name:,
      shipper_phone:,
      shipper_reference:
    )
      accessorials = build_accessorials(accessorials: accessorials, packages: packages)

      mode = @conf.dig(:services, :mappable, service.to_sym)

      shipper_phone = shipper_phone.gsub(/\s+/, '').gsub(/[()-+.]/, '')
      shipper_phone = shipper_phone[1..] if shipper_phone.length == 11

      receiver_phone = receiver_phone.gsub(/\s+/, '').gsub(/[()-+.]/, '')
      receiver_phone = receiver_phone[1..] if receiver_phone.length == 11

      items = []
      i = 0
      packages.each do |package|
        # package_type = package.type.pallet? ? 'PALLET' : ''
        package_type = 'PALLET'

        i += 1
        items << {
          Id: i.to_s,
          FreightClasses: {
            FreightClass: package.freight_class.to_s,
            Type: ''
          },
          Dimensions: {
            Height: package.height(:in).ceil,
            Length: package.length(:in).ceil,
            Uom: 'in',
            Width: package.width(:in).ceil
          },
          HazardousMaterial: package.hazmat?,
          Description: package.description,
          Quantities: {
            Actual: package.quantity,
            Uom: package_type
          },
          Weights: {
            Actual: package.pounds(:total).ceil,
            Uom: 'lb'
          }
        }
      end

      body = {
        Comments: {
          Comment: '',
          Type: 'SpecialInstructions'
        },
        Consignee: {
          AddressLine1: destination.to_hash[:street1],
          City: destination.to_hash[:city],
          Contact: {
            Name: receiver_contact_name,
            Phone: receiver_phone,
            Fax: '',
            Email: ''
          },
          CountryCode: 'USA',
          IsResidential: accessorials.include?(:residential_pickup),
          Name: receiver_name,
          PostalCode: destination.to_hash[:postal_code],
          StateProvince: destination.to_hash[:province]
        },
        Dates: {
          EarliestPickupDate: "#{pickup_from.iso8601[..-7]}Z",
          LatestPickupDate: "#{pickup_to.iso8601[..-7]}Z",
          EarliestDropDate: "#{delivery_from.iso8601[..-7]}Z",
          LatestDropDate: "#{delivery_to.iso8601[..-7]}Z"
        },
        Items: items,
        Payment: {
          Address: {
            IsResidential: false,
            LocationCode: 'MNP9C1C',
            PostalCode: '60490'
          }
        },
        Pricesheets: [
          {
            IsSelected: true,
            Mode: mode,
            Scac: scac,
            Type: 'Carrier'
          }
        ],
        ReferenceNumbers: [
          {
            IsPrimary: true,
            ReferenceNumber: shipper_reference.to_s,
            Type: 'Ship Ref'
          },
          {
            IsPrimary: false, # must have one true
            ReferenceNumber: customer_reference.to_s,
            Type: 'PO Number'
          }
        ],
        ServiceFlags: accessorials,
        Shipper: {
          AddressLine1: origin.to_hash[:street1],
          City: origin.to_hash[:city],
          Contact: {
            Name: shipper_contact_name,
            Phone: shipper_phone,
            Fax: '',
            Email: ''
          },
          CountryCode: 'USA',
          IsResidential: accessorials.include?(:residential_pickup),
          Name: shipper_name,
          PostalCode: origin.to_hash[:postal_code],
          StateProvince: origin.to_hash[:province]
        },
        Status: 'pending'
      }.to_json

      request = {
        url: request_url(:pickup),
        method: @conf.dig(:api, :methods, :pickup),
        body: body
      }

      request[:headers] = build_headers

      save_request(request)
      request
    end

    def parse_pickup_response(response)
      parse_response(response)&.dig('PrimaryReference')
    end

    # Rates

    def build_rate_request(origin, destination, packages, options = {})
      options = @options.merge(options)

      accessorials = build_accessorials(accessorials: options[:accessorials], packages: packages)

      items = []
      packages.each do |package|
        items << {
          Name: 'Freight',
          FreightClass: package.freight_class.to_s,
          Weight: package.pounds(:total).ceil.to_s,
          WeightUnits: 'lb',
          Width: package.width(:in).ceil,
          Length: package.length(:in).ceil,
          Height: package.height(:in).ceil,
          DimensionUnits: 'in',
          Quantity: package.quantity,
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
        headers: build_headers(options),
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
        next if response_line['Message'] # Signifies error

        cost = response_line['Total']
        next if cost.blank?

        cost = (cost.to_f * 100).to_i
        service = response_line['Charges'].map { |charges| charges['Description'] }
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
        transit_days = response_line['ServiceDays'].to_i
        rate_estimates << RateEstimate.new(
          origin,
          destination,
          { scac: response_line['Scac'], name: response_line['CarrierName'] },
          service,
          transit_days: transit_days,
          estimate_reference: nil,
          total_cost: cost,
          total_price: cost,
          currency: 'USD',
          with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
        )
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
