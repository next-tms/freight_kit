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

    def overlength_fees_require_tariff?
      false
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
      delivery_from:,
      delivery_to:,
      dispatcher:,
      pickup_from:,
      pickup_to:,
      scac:,
      service:,
      shipment:
    )
      request = build_pickup_request(
        delivery_from:,
        delivery_to:,
        dispatcher:,
        pickup_from:,
        pickup_to:,
        scac:,
        service:,
        shipment:
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

    def find_rates(shipment:)
      # Not necessary
      # validate_packages(packages)

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit(request))
    end

    def find_rates_implemented?
      true
    end

    # Tracking

    def valid_tracking_number?(tracking_number)
      pro[..2] == 'UAP' && pro.length == 13
    end

    protected

    def build_accessorials(shipment:)
      serviceable_accessorials?(shipment.accessorials)

      parsed_accessorials = []

      shipment.accessorials.each do |a|
        unless @conf.dig(:accessorials, :unserviceable).include?(a)
          parsed_accessorials << { ServiceCode: @conf.dig(:accessorials, :mappable)[a] }
        end
      end

      longest_dimension_ft = shipment.packages.map { |p| [p.width(:feet), p.length(:feet)].max }.max.ceil
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
        HTTParty.post(url, headers:, body:)
      else
        HTTParty.get(url, headers:)
      end
    end

    def parse_response(response)
      case response.code
      when 204
        return {}
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
      "https://#{@conf.dig(:api, :domains, env, action)}#{@conf.dig(:api, :endpoints, action)}"
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
      browser
        .iframe(name: 'AppBody')
        .frame(id: 'Header')
        .select(name: 'column')
        .select('Primary Reference')
      browser
        .iframe(name: 'AppBody')
        .frame(id: 'Header')
        .select(name: 'condition')
        .select('=')
      browser
        .iframe(name: 'AppBody')
        .frame(id: 'Header')
        .text_field(name: 'filter')
        .set(tracking_number)
      browser
        .iframe(name: 'AppBody')
        .frame(id: 'Header')
        .button(value: 'Find')
        .click

      begin
        browser
          .iframe(name: 'AppBody')
          .frame(id: 'Detail')
          .iframe(id: 'transportsWin')
          .element(xpath: '/html/body/div/table/tbody/tr[2]/td[1]/span/a[2]')
          .wait_until(&:present?)
          .click

        browser
          .iframe(name: 'AppBody')
          .frame(id: 'Detail')
          .element(xpath: '/html/body/div[1]/div/div/div[1]/div[1]/div[2]/div/a[5]')
          .wait_until(&:present?)
          .click
      rescue Watir::Wait::TimeoutError
        # POD not yet available
        browser.close
        raise Interstellar::DocumentNotFoundError, "API Error: #{self.class.name}: Document not found"
      end

      html = browser
             .iframe(name: 'AppBody').frame(id: 'Detail').iframes[1]
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
      delivery_from:,
      delivery_to:,
      dispatcher:,
      pickup_from:,
      pickup_to:,
      scac:,
      service:,
      shipment:
    )
      accessorials = build_accessorials(shipment:)

      mode = @conf.dig(:services, :mappable, service.to_sym)

      shipper_phone = shipment.origin.contact.phone.gsub(/\s+/, '').gsub(/[()-+.]/, '')
      shipper_phone = shipper_phone[1..] if shipper_phone.length == 11

      receiver_phone = shipment.destination.contact.phone.gsub(/\s+/, '').gsub(/[()-+.]/, '')
      receiver_phone = receiver_phone[1..] if receiver_phone.length == 11

      items = []
      i = 0
      shipment.packages.each do |package|
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
          AddressLine1: shipment.destination.address1,
          City: shipment.destination.city,
          Contact: {
            Name: shipment.destination.contact.name,
            Phone: receiver_phone,
            Fax: '',
            Email: ''
          },
          CountryCode: shipment.destination.country.code(:alpha3),
          IsResidential: shipment.accessorials.include?(:residential_pickup),
          Name: shipment.destination.contact.company_name,
          PostalCode: shipment.destination.zip,
          StateProvince: shipment.destination.state
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
            ReferenceNumber: shipment.order_number.to_s,
            Type: 'Ship Ref'
          },
          {
            IsPrimary: false, # must have one true
            ReferenceNumber: shipment.po_number.to_s,
            Type: 'PO Number'
          }
        ],
        ServiceFlags: accessorials,
        Shipper: {
          AddressLine1: shipment.origin.address1,
          City: shipment.origin.city,
          Contact: {
            Name: shipment.origin.contact.name,
            Phone: shipper_phone,
            Fax: '',
            Email: ''
          },
          CountryCode: shipment.origin.country.code(:alpha3),
          IsResidential: shipment.accessorials.include?(:residential_pickup),
          Name: shipment.origin.contact.company_name,
          PostalCode: shipment.origin.zip,
          StateProvince: shipment.origin.state
        },
        Status: 'pending'
      }.to_json

      request = {
        url: request_url(:pickup),
        method: @conf.dig(:api, :methods, :pickup),
        body:
      }

      request[:headers] = build_headers

      save_request(request)
      request
    end

    def parse_pickup_response(response)
      pickup_number = parse_response(response)&.dig('PrimaryReference')
      error = pickup_number.blank? ? Interstellar::ResponseError.new('API Error: Unknown response') : nil

      Interstellar::PickupResponse.new(error:, pickup_number:)
    end

    # Rates

    def build_rate_request(shipment:)
      accessorials = build_accessorials(shipment:)

      items = []
      shipment.packages.each do |package|
        items << {
          Name: package.description,
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

      pickup_date = DateTime.now + 1.day

      body = {
        Constraints: {
          ServiceFlags: accessorials
        },
        Items: items,
        PickupEvent: {
          City: shipment.origin.city.upcase,
          Country: shipment.origin.country_code(:alpha3),
          Date: pickup_date.strftime('%m/%d/%Y %I:%M:00 %p'),
          LocationCode: 'PLocationCode',
          State: shipment.origin.state.upcase,
          Zip: shipment.origin.zip.to_s.upcase
        },
        DropEvent: {
          City: shipment.destination.city.upcase,
          Country: shipment.destination.country_code(:alpha3),
          Date: (DateTime.now + 5.days).strftime('%m/%d/%Y %I:%M:00 %p'),
          LocationCode: 'DLocationCode',
          MaxPriceSheet: 6,
          ShowInsurance: false,
          State: shipment.destination.state.upcase,
          Zip: shipment.destination.zip.to_s.upcase
        }
      }.to_json

      request = {
        url: request_url(:quote),
        headers: build_headers(@options),
        method: @conf.dig(:api, :methods, :quote),
        body:
      }

      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:)
      response = parse_response(response)

      raise UnserviceableError, 'No rates found' if response.blank?

      rates = []

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

        rates << Rate.new(
          carrier_name: response_line['CarrierName'],
          carrier: self,
          currency: 'USD',
          prices: [Price.new(blame: :api, cents: cost, description: response_line['CarrierName'])],
          scac: response_line['Scac']&.upcase,
          service_name: service,
          shipment:,
          transit_days:,
          with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
        )
      end

      RateResponse.new(rates:, request: last_request, response:)
    end

    # Tracking
  end
end
