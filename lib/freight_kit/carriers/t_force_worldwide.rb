module FreightKit
  module Carriers
    class TForceWorldwide < FreightKit::Carrier
      class << self
        def acts_as_broker? = true
        def bol_requires_tracking_number? = true

        def check_mailing_addresses
          [
            Address.new(
              city: 'Cleveland',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '08174d66-749f-4410-b9e2-47e1029c22e1',
              postal_code: '44193',
              region_abbreviation: 'OH',
              street: 'PO Box 932721'
            )
          ]
        end

        def id = '7c0db80c-a73d-415c-a8c2-76da048f2e0b'
        def legal_name = 'TForce Worldwide Inc'

        def mappable_accessorials
          {
            airport_delivery: 'LADAIRP',
            airport_pickup: 'LAPAIRP',
            amusement_park_delivery: 'LADFAIR',
            amusement_park_pickup: 'LAPFAIR',
            appointment_delivery: 'APPT',
            athletic_facility_delivery: 'LADRECR',
            athletic_facility_pickup: 'LAPRECR',
            brewery_delivery: 'LADWINE',
            brewery_pickup: 'LAPWINE',
            church_delivery: 'LADCHUR',
            church_pickup: 'LAPCHUR',
            construction_delivery: 'CONSL',
            construction_pickup: 'LAPCONS',
            convention_delivery: 'CONV1',
            convention_pickup: 'CONV2',
            fair_delivery: 'LADFAIR',
            fair_pickup: 'LAPFAIR',
            farm_delivery: 'LADFARM',
            farm_pickup: 'LAPFARM',
            fitness_center_delivery: 'LADRECR',
            fitness_center_pickup: 'LAPRECR',
            golf_course_delivery: 'LADGOLF',
            golf_course_pickup: 'LAPGOLF',
            government_delivery: 'LADGOVE',
            government_pickup: 'LAPGOVE',
            grocery_warehouse_delivery: 'LADGROC',
            grocery_warehouse_pickup: 'LAPGROC',
            guaranteed_delivery_am: 'GSAM',
            guaranteed_delivery_pm: 'GSPM',
            guaranteed_delivery: 'GLTL',
            hospital_delivery: 'LADHOSP',
            hospital_pickup: 'LAPHOSP',
            hotel_delivery: 'LADRESO',
            hotel_pickup: 'LAPRESO',
            inside_delivery: 'IDL',
            inside_pickup: 'IPU',
            inspection_site_delivery: 'LADINSP',
            inspection_site_pickup: 'LAPINSP',
            jobsite_delivery: 'LADCONS',
            jobsite_pickup: 'LAPCONS',
            liftgate_delivery: 'LG1',
            liftgate_pickup: 'LG2',
            mall_delivery: 'LADMALL',
            mall_pickup: 'LAPMALL',
            military_site_delivery: 'LADMILI',
            military_site_pickup: 'LAPMILI',
            mine_site_delivery: 'LADMINE',
            mine_site_pickup: 'LAPMINE',
            motel_delivery: 'LADRESO',
            motel_pickup: 'LAPRESO',
            nursing_home_delivery: 'LADNURS',
            nursing_home_pickup: 'LAPNURS',
            park_delivery: 'LADPARK',
            park_pickup: 'LAPPARK',
            prison_delivery: 'LADPRIS',
            prison_pickup: 'LAPPRIS',
            ranch_delivery: 'LADRANC',
            ranch_pickup: 'LAPRANC',
            reservation_delivery: 'LADRESE',
            reservation_pickup: 'LAPRESE',
            residential_delivery: 'RES1',
            residential_pickup: 'RES2',
            resort_delivery: 'LADRESO',
            resort_pickup: 'LAPRESO',
            restaurant_delivery: 'LADREST',
            restaurant_pickup: 'LAPREST',
            school_delivery: 'LADSCHO',
            school_pickup: 'LAPSCHO',
            steel_mill_delivery: 'LADSTEE',
            steel_mill_pickup: 'LAPSTEE',
            storage_facility_delivery: 'LADMINI',
            storage_facility_pickup: 'LAPMINI',
            university_delivery: 'LADSCHO',
            university_pickup: 'LAPSCHO',
            utility_site_delivery: 'LADUTLI',
            utility_site_pickup: 'LAPUTLI',
            winery_delivery: 'LADWINE',
            winery_pickup: 'LAPWINE'
          }
        end

        def name = 'TForce Worldwide'
        def overlength_fees_require_tariff? = false
        def pickup_number_is_tracking_number? = true
        def required_credential_types = %i[api selenoid website]
        def requirements = %i[credentials]
        def scac = 'DRRQ'

        def unquotable_accessorials
          %i[
            afterhours_delivery
            afterhours_pickup
            cemetery_delivery
            cemetery_pickup
            dock_dropoff
            dock_pickup
            grocery_store_delivery
            grocery_store_pickup
          ]
        end

        def unserviceable_accessorials
          %i[
            appointment_pickup
            customs_brokerage
            early_morning_delivery
            early_morning_pickup
            flatbed_delivery
            flatbed_pickup
            marina_delivery
            marina_pickup
          ]
        end

        def us_dot_number = 3_481_358
        def us_mc_number = 283_221
        def valid_number_regexes = { tracking_number: /\AUAP.{10}\z/ }
      end

      API = {
        domains: {
          production: {
            bol: 'connectapi.tfwwi.com',
            pickup: 'connectapi.tfwwi.com',
            pod: 'rrd.mercurygate.net',
            quote: 'connectapi.tfwwi.com'
          },
          staging: {
            bol: 'connectapi-stage.tfwwi.com',
            pickup: 'connectapi-stage.tfwwi.com',
            pod: 'rrd.mercurygate.net',
            quote: 'connectapi-stage.tfwwi.com'
          }
        },
        endpoints: {
          bol: '/services/api/v1/Shipment/documentExtract?primaryReferenceBol=%TRACKING_NUMBER%',
          pickup: '/services/api/v1/Shipment/Import',
          pod: '/MercuryGate/login/mgLogin.jsp?inline=true',
          quote: '/services/api/v1/RateShop/RateRequest'
        },
        methods: { bol: :get, pickup: :post, pod: :get, quote: :post }
      }.freeze
      JSON_HEADERS = { Accept: 'application/json', 'Content-Type': 'application/json', charset: 'utf-8' }.freeze
      SERVICE_CODES = {
        guaranteed_delivery: 'Standard LTL Guarantee',
        guaranteed_delivery_am: 'Guaranteed LTL Service AM',
        guaranteed_delivery_pm: 'Guaranteed LTL Service PM',
        standard: 'LTL'
      }.freeze

      # Documents

      def bol(tracking_number)
        request = build_document_request(:bol, tracking_number)
        parse_bol_response(commit(request), :bol, tracking_number)
      end

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

      def find_rates(shipment:)
        # Not necessary
        # validate_packages(packages)

        request = build_rate_request(shipment:)
        parse_rate_response(shipment:, response: commit(request))
      end

      def pod(tracking_number) = parse_pod_response(tracking_number)
      def valid_tracking_number?(tracking_number) = valid_number_regex(:tracking_number).match?(tracking_number)

      protected

      def build_accessorials(shipment:)
        serviceable_accessorials?(shipment.accessorials)

        parsed_accessorials = []

        shipment.accessorials.each do |a|
          parsed_accessorials << { ServiceCode: mappable_accessorials[a] } if unserviceable_accessorials.exclude?(a)
        end

        longest_dimension_ft = shipment.packages.map { |p| [p.width(:feet), p.length(:feet)].max }.max.ceil
        parsed_accessorials << { ServiceCode: "OVL#{longest_dimension_ft}" } if longest_dimension_ft >= 8 && longest_dimension_ft < 30

        parsed_accessorials.uniq.to_a
      end

      def build_document_request(type, tracking_number, _options = {})
        request = { url: request_url(type).sub('%TRACKING_NUMBER%', tracking_number), method: API.dig(:methods, type) }

        request[:headers] = build_headers if type == :bol

        save_request(request)
        request
      end

      def build_headers
        api_credentials = fetch_credential(:api)

        JSON_HEADERS.merge({ ApiKey: api_credentials.password, UserName: api_credentials.username })
      end

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

        mode = SERVICE_CODES[service.to_sym]

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
            FreightClasses: { FreightClass: package.freight_class.to_s, Type: '' },
            Dimensions: {
              Height: package.height(:in).ceil,
              Length: package.length(:in).ceil,
              Uom: 'in',
              Width: package.width(:in).ceil
            },
            HazardousMaterial: package.hazmat?,
            Description: package.description,
            Quantities: { Actual: package.quantity, Uom: package_type },
            Weights: { Actual: package.pounds(:total).ceil, Uom: 'lb' }
          }
        end

        body = {
          Comments: { Comment: '', Type: 'SpecialInstructions' },
          Consignee: {
            AddressLine1: shipment.destination.address1,
            City: shipment.destination.city,
            Contact: { Name: shipment.destination.contact.name, Phone: receiver_phone, Fax: '', Email: '' },
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
          Payment: { Address: { IsResidential: false, LocationCode: 'MNP9C1C', PostalCode: '60490' } },
          Pricesheets: [{ IsSelected: true, Mode: mode, Scac: scac, Type: 'Carrier' }],
          ReferenceNumbers: [
            { IsPrimary: true, ReferenceNumber: shipment.order_number.to_s, Type: 'Ship Ref' },
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
            Contact: { Name: shipment.origin.contact.name, Phone: shipper_phone, Fax: '', Email: '' },
            CountryCode: shipment.origin.country.code(:alpha3),
            IsResidential: shipment.accessorials.include?(:residential_pickup),
            Name: shipment.origin.contact.company_name,
            PostalCode: shipment.origin.postal_code,
            StateProvince: shipment.origin.province
          },
          Status: 'pending'
        }.to_json

        request = { url: request_url(:pickup), method: API.dig(:methods, :pickup), body: }

        request[:headers] = build_headers

        save_request(request)
        request
      end

      def build_rate_request(shipment:)
        accessorials = build_accessorials(shipment:)

        items = shipment.packages.map do |package|
          {
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
          Constraints: { ServiceFlags: accessorials },
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

        request = { url: request_url(:quote), headers: build_headers, method: API.dig(:methods, :quote), body: }

        save_request(request)
        request
      end

      def commit(request)
        url = request[:url]
        headers = request[:headers]
        method = request[:method]
        body = request[:body]

        case method
        when :post
          HTTPClient.post(url, headers:, body:)
        else
          HTTPClient.get(url, headers:)
        end
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
          browser.element(xpath: '//*[@id="__AppFrameBaseTable"]/tbody/tr[2]/td/div[4]')
                 .click
        rescue Selenium::WebDriver::Error::UnexpectedAlertOpenError => e
          browser.close

          message = e.message[/{(.*?)}/m, 1]&.split(':')&.last
          message = message&.squish

          document_response.error = InvalidCredentialsError.new(message)
          return document_response
        end

        browser.iframes(src: '../mainframe/MainFrame.jsp?bRedirect=true')
        browser.iframe(name: 'AppBody').frame(id: 'Header').select(name: 'column').select('Primary Reference')
        browser.iframe(name: 'AppBody').frame(id: 'Header').select(name: 'condition').select('=')
        browser.iframe(name: 'AppBody').frame(id: 'Header').text_field(name: 'filter').set(tracking_number)
        browser.iframe(name: 'AppBody').frame(id: 'Header').button(value: 'Find')
               .click

        begin
          browser.iframe(name: 'AppBody').frame(id: 'Detail').iframe(id: 'transportsWin')
                 .element(xpath: '/html/body/div/table/tbody/tr[2]/td[1]/span/a[2]')
                 .wait_until(&:present?)
                 .click

          browser.iframe(name: 'AppBody').frame(id: 'Detail')
                 .element(xpath: '/html/body/div[1]/div/div/div[1]/div[1]/div[2]/div/a[5]')
                 .wait_until(&:present?)
                 .click
        rescue Watir::Wait::TimeoutError
          # POD not yet available
          browser.close

          document_response.error = FreightKit::DocumentNotFoundError.new
          return document_response
        end

        html = browser.iframe(name: 'AppBody').frame(id: 'Detail').iframes[1].element(xpath: '/html/body/table[3]')
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
          response = HTTPClient.get(url)
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
            with_excessive_length_fees: rates_with_excessive_length_fees?
          )
        end

        rate_response.rates = rates
        rate_response
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

      def request_url(action) = "https://#{API.dig(:domains, :production, action)}#{API.dig(:endpoints, action)}"

      # Tracking
    end
  end
end
