# frozen_string_literal: true

module FreightKit
  class DRRQ < FreightKit::Carrier
    class << self
      def overlength_fees_require_tariff?
        false
      end

      def pickup_number_is_tracking_number?
        true
      end

      def required_credential_types
        %i[api selenoid website]
      end

      def requirements
        %i[credentials]
      end
    end

    REACTIVE_FREIGHT_CARRIER = true

    JSON_HEADERS = {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      charset: 'utf-8'
    }.freeze

    cattr_reader :name, :scac
    @@name = 'TForce Worldwide'
    @@scac = 'DRRQ'

    # Documents

    def bol_requires_tracking_number?
      true
    end

    def bol(tracking_number)
      request = build_document_request(:bol, tracking_number)
      parse_bol_response(commit(request), :bol, tracking_number)
    end

    def pod(tracking_number)
      parse_pod_response(tracking_number)
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
        shipment:,
      )

      parse_pickup_response(commit(request))
    end

    # Rates

    def find_rates(shipment:)
      # Not necessary
      # validate_packages(packages)

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit(request))
    end

    # Tracking

    def valid_tracking_number?(tracking_number)
      tracking_number[..2] == 'UAP' && tracking_number.length == 13
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

    def build_headers
      api_credentials = fetch_credential(:api)

      JSON_HEADERS.merge({ ApiKey: api_credentials.password, UserName: api_credentials.username })
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
        raise FreightKit::InvalidCredentialsError, "HTTP #{response.code}: #{response}"
      end

      raise FreightKit::ResponseError, "HTTP #{response.code}: #{response}" if response.code != 200

      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise FreightKit::ResponseError
      end
    end

    def request_url(action)
      "https://#{@conf.dig(:api, :domains, :production, action)}#{@conf.dig(:api, :endpoints, action)}"
    end

    # Documents

    def build_document_request(type, tracking_number, options = {})
      request = {
        url: request_url(type).sub('%TRACKING_NUMBER%', tracking_number),
        method: @conf.dig(:api, :methods, type)
      }

      request[:headers] = build_headers if type == :bol

      save_request(request)
      request
    end

    def parse_bol_response(response, _type, _tracking_number)
      response = parse_response(response)
      document_response = DocumentResponse.new(request: last_request, response:)

      file_bytes = response['FileBytes']

      if file_bytes.blank?
        document_response.error = DocumentNotFoundError.new
        return document_response
      end

      data = Base64.decode64(file_bytes)

      document_response.assign_attributes(content_type: 'application/pdf', data:)
      document_response
    end

    def parse_pod_response(tracking_number)
      document_response = DocumentResponse.new

      request = build_document_request(:pod, tracking_number)

      selenoid_credentials = fetch_credential(:selenoid)
      website_credentials = fetch_credential(:website)

      browser = Watir::Browser.new(*selenoid_credentials.watir_args)
      browser.goto(request[:url])

      if browser.html.downcase.include?('unable to process request')
        browser.close

        document_response.error = ResponseError.new
        return document_response
      end

      begin
        browser.text_field(name: 'UserId').set(website_credentials.username)
        browser.text_field(name: 'Password').set(website_credentials.password)
        browser.button(name: 'submitbutton').click
      rescue Selenium::WebDriver::Error::UnexpectedAlertOpenError
        browser.close

        document_response.error = InvalidCredentialsError.new
        return document_response
      end

      logout_url = 'https://rrd.mercurygate.net/MercuryGate/login/urlRedirect.jsp?Logout=true'

      begin
        browser
        .element(xpath: '//*[@id="__AppFrameBaseTable"]/tbody/tr[2]/td/div[4]')
        .click
      rescue Selenium::WebDriver::Error::UnexpectedAlertOpenError => e
        browser.close

        message = e.message[/{(.*?)}/m, 1]&.split(':')&.last&.squish

        document_response.error = InvalidCredentialsError.new(message)
        return document_response
      end

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

        document_response.error = FreightKit::DocumentNotFoundError.new
        return document_response
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

      if url.blank?
        document_response.error = FreightKit::DocumentNotFoundError.new
        return document_response
      end

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
          PostalCode: shipment.destination.postal_code,
          StateProvince: shipment.destination.province
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
                       },
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
                            },
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
          PostalCode: shipment.origin.postal_code,
          StateProvince: shipment.origin.province
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
      pickup_response = PickupResponse.new(request: last_request, response:)

      pickup_number = parse_response(response)&.dig('PrimaryReference')

      if pickup_number.blank?
        pickup_response.error = FreightKit::ResponseError.new('Unknown response')
        return pickup_response
      end

      pickup_response.pickup_number = pickup_number
      pickup_response
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

      pickup_event_date = shipment.pickup_at.date_time_with_zone
      drop_event_date = (pickup_event_date + 7.days).beginning_of_day + 12.hours

      body = {
        Constraints: {
          ServiceFlags: accessorials
        },
        Items: items,
        PickupEvent: {
          City: shipment.origin.city.upcase,
          Country: shipment.origin.country.code(:alpha3).value,
          Date: pickup_event_date.strftime('%m/%d/%Y %I:%M:00 %p'),
          LocationCode: 'PLocationCode',
          State: shipment.origin.province.upcase,
          Zip: shipment.origin.postal_code.to_s.upcase
        },
        DropEvent: {
          City: shipment.destination.city.upcase,
          Country: shipment.destination.country.code(:alpha3).value,
          Date: drop_event_date.strftime('%m/%d/%Y %I:%M:00 %p'),
          LocationCode: 'DLocationCode',
          MaxPriceSheet: 6,
          ShowInsurance: false,
          State: shipment.destination.province.upcase,
          Zip: shipment.destination.postal_code.to_s.upcase
        }
      }.to_json

      request = {
        url: request_url(:quote),
        headers: build_headers,
        method: @conf.dig(:api, :methods, :quote),
        body:
      }

      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:)
      rate_response = RateResponse.new(request: last_request, response:)
      response = parse_response(response)

      if response.blank?
        rate_response.error = UnserviceableError.new('No rates found')
        return rate_response
      end

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
          with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees),
        )
      end

      rate_response.rates = rates
      rate_response
    end

    # Tracking
  end
end
