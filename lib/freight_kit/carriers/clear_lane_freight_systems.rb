module FreightKit
  module Carriers
    class ClearLaneFreightSystems < FreightKit::Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Rancho Cucamonga',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: '522c3717-d8f1-45c1-a363-da48dadd3090',
              postal_code: '91730',
              region_abbreviation: 'CA',
              street: '9278 Charles Smith Ave'
            )
          ]
        end

        # @note Explicitly set to `false` because though API allows this, it "doesn't quote correctly" per customer
        # service
        def find_rates_with_declared_value? = false

        def id = '5fe13653-7ac8-4c82-977a-ba9e83ea92e6'

        def mappable_accessorials
          {
            inside_delivery: 'INSD',
            inside_pickup: 'INSP',
            liftgate_delivery: 'LIFTD',
            liftgate_pickup: 'LIFTP',
            residential_delivery: 'RESDLY',
            residential_pickup: 'RESPU'
          }
        end

        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(8, :feet)
        def name = 'Clear Lane Freight Systems'
        def overlength_fees_require_tariff? = false
        def required_credential_types = %i[api website]
        def requirements = %i[credentials]
        def scac = 'CLNI'
        def unquotable_accessorials = %i[appointment_delivery]

        def unserviceable_accessorials
          %i[
            afterhours_delivery
            afterhours_pickup
            airport_delivery
            airport_pickup
            amusement_park_delivery
            amusement_park_pickup
            appointment_pickup
            athletic_facility_delivery
            athletic_facility_pickup
            brewery_delivery
            brewery_pickup
            cemetery_delivery
            cemetery_pickup
            church_delivery
            church_pickup
            construction_delivery
            construction_pickup
            convention_delivery
            convention_pickup
            customs_brokerage
            dock_dropoff
            dock_pickup
            driver_assist
            early_morning_delivery
            early_morning_pickup
            fair_delivery
            fair_pickup
            farm_delivery
            farm_pickup
            fitness_center_delivery
            fitness_center_pickup
            flatbed_delivery
            flatbed_pickup
            golf_course_delivery
            golf_course_pickup
            government_delivery
            government_pickup
            grocery_store_delivery
            grocery_store_pickup
            grocery_warehouse_delivery
            grocery_warehouse_pickup
            guaranteed_delivery
            guaranteed_delivery_am
            guaranteed_delivery_pm
            hospital_delivery
            hospital_pickup
            hotel_delivery
            hotel_pickup
            inspection_site_delivery
            inspection_site_pickup
            jobsite_delivery
            jobsite_pickup
            mall_delivery
            mall_pickup
            marina_delivery
            marina_pickup
            military_site_delivery
            military_site_pickup
            mine_site_delivery
            mine_site_pickup
            motel_delivery
            motel_pickup
            nursing_home_delivery
            nursing_home_pickup
            park_delivery
            park_pickup
            prison_delivery
            prison_pickup
            ranch_delivery
            ranch_pickup
            reservation_delivery
            reservation_pickup
            resort_delivery
            resort_pickup
            restaurant_delivery
            restaurant_pickup
            school_delivery
            school_pickup
            steel_mill_delivery
            steel_mill_pickup
            storage_facility_delivery
            storage_facility_pickup
            university_delivery
            university_pickup
            utility_site_delivery
            utility_site_pickup
            winery_delivery
            winery_pickup
          ]
        end

        def validate_packages(packages, tariff = nil)
          raise UnserviceableError, 'Must be fewer than 10 items altogether' if packages.sum(&:quantity) > 10

          super
        end
      end

      include FreightKit::Rateable

      API = {
        actions: { rates: :get_rating },
        domain: 'ssworldtrak.com',
        endpoints: { rates: '/WTKServicesCLEARL/GetRating.asmx?WSDL' },
        use_ssl: true
      }.freeze
      WEBSITE = { login: 'https://ssworldtrak.com/WebtrakWTNew/' }.freeze

      # Documents

      def pod(tracking_number) = parse_document_response(:pod, tracking_number)
      def scanned_bol(tracking_number) = parse_document_response(:bol, tracking_number)

      # Rates

      # Tracking

      protected

      def accessorial_output_description(accessorial_output)
        return '' if accessorial_output[:accessorial_desc].blank?

        description = accessorial_output[:accessorial_desc]
        description = description.capitalize
        description.gsub('Smc', 'SMC')
      end

      def build_commodity_input(packages)
        packages.map do |package|
          {
            CommodityInput: {
              CommodityClass: package.freight_class,
              CommodityHazmat: package.hazmat? ? 'Y' : 'N',
              CommodityHeight: package.height(:in).ceil,
              CommodityLength: package.length(:in).ceil,
              CommodityPieces: package.quantity,
              CommodityPieceType: package.packaging.pallet? ? 'pallet' : 'box',
              CommodityWeight: package.pounds(:total).ceil,
              CommodityWeightPerPiece: package.pounds(:each).ceil,
              CommodityWidth: package.width(:in).ceil
            }
          }
        end
      end

      def build_rate_request(shipment:)
        accessorial_input = []
        if shipment.accessorials.present?
          serviceable_accessorials?(shipment.accessorials)
          shipment.accessorials.each do |a|
            next if unserviceable_accessorials.include?(a)

            accessorial_input << { AccessorialInput: { AccessorialCode: mappable_accessorials[a] } }
          end
        end

        accessorial_input.uniq!

        commodity_input = build_commodity_input(shipment.packages)

        palletized = shipment.packages.all? { |package| package.packaging.pallet? } ? 'Y' : 'N'

        pickup_from = ::Time.current.beginning_of_day + 14.hours
        pickup_from += 1.day if ::Time.current > pickup_from
        pickup_to = pickup_from + 3.hours

        api_credentials = fetch_credential(:api)

        request = {
          RatingParam: {
            AccessorialInput: accessorial_input,
            CommodityInput: commodity_input,
            RatingInput: {
              DeclaredValue: 0,
              DestinationCity: shipment.destination.city,
              DestinationCountry: shipment.destination.country.code(:alpha2).value,
              DestinationState: shipment.destination.province,
              DestinationZip: shipment.destination.postal_code,
              LiabilityType: '',
              OriginCity: shipment.origin.city,
              OriginCountry: shipment.origin.country.code(:alpha2).value,
              OriginState: shipment.origin.province,
              OriginZip: shipment.origin.postal_code,
              Palletized: palletized,
              PickupDate: pickup_from.to_date.strftime('%Y-%m-%d'),
              PickupLocationCloseTime: pickup_to.strftime('%H:%M:00'),
              PickupTime: pickup_from.strftime('%H:%M:00'),
              RequestID: rand(0..999_999).to_s,
              ServiceLevelID: '',
              ShipmentTerms: '',
              Stackable: false,
              WebTrakUserID: api_credentials.username
            }
          }
        }

        save_request(request)
        request
      end

      def build_url(api_or_website, action)
        case api_or_website
        when :api
          scheme = API[:use_ssl] ? 'https://' : 'http://'
          "#{scheme}#{API[:domain]}#{API.dig(:endpoints, action)}"
        when :website
          WEBSITE[action]
        end
      end

      def commit(action, request)
        client_args = {
          wsdl: build_url(:api, action),
          convert_request_keys_to: :none,
          env_namespace: :soap,
          element_form_default: :qualified
        }

        call_args = { message: request_blueprint.deep_merge(request) }

        ::FreightKit::SoapClient.new(
          carrier: self,
          action:,
          client_args:,
          call_args:,
          soap_operation: API.dig(:actions, action)
        ).call&.to_hash&.with_indifferent_access
      end

      def parse_amount(amount)
        ['$', ','].each do |char|
          amount = amount.sub(char, '')
        end

        return 0 if amount.blank?

        amount = (amount.to_f * 100).to_i
      end

      def parse_document_response(action, tracking_number)
        document_response = DocumentResponse.new

        selenoid_credential = fetch_credential(:selenoid)
        website_credentials = fetch_credential(:website)

        browser = Watir::Browser.new(*selenoid_credential.watir_args)
        browser.goto('https://ssworldtrak.com/WebtrakWTNew/')

        browser.text_field(name: 'txtUserId').set(website_credentials.username)
        browser.text_field(name: 'txtPass').set(website_credentials.password)
        browser.button(name: 'btnSubmit').click

        if browser.html.include?('Either UserID or Password are incorrect, please try again.')
          browser.close

          document_response.error = InvalidCredentialsError.new
          return document_response
        end

        # Bypass the hover menu
        browser.goto('https://ssworldtrak.com/WebtrakWTNew/Main/Reports/POD.aspx')

        from = 90.days.ago.strftime('%m%d%Y')

        browser.text_field(name: 'txtFromDate').wait_until(&:present?).focus

        # Hack to get around JavaScript messing up our input
        sleep(1)
        from.chars.each do |char|
          browser.text_field(name: 'txtFromDate').append(char)
        end

        browser.text_field(name: 'txtToDate').click
        browser.element(xpath: '/html/body/form/div[3]/div[4]/div[3]/div[2]/div/div/div[3]/div').wait_until(&:present?)
               .click

        browser.button(name: 'btnSubmit').click

        browser.text_field(id: 'yadcf-filter--grid-2').set(tracking_number)
        browser.send_keys(:enter)

        if browser.element(id: 'tdPODName0').wait_until(&:present?).text == 'NO POD' && action == :pod
          browser.window.close
          browser.original_window.use
          browser.goto('https://ssworldtrak.com/WebtrakWTNew/logoff.aspx')
          browser.close

          document_response.error = DocumentNotFoundError.new
          return document_response
        end

        browser.element(xpath: '/html/body/form/div[3]/div[4]/div[8]/div/table/tbody/tr/td[12]/a')
               .wait_until(&:present?)
               .click

        browser.switch_window

        sleep(5)

        html = browser.element(id: 'DataTables_Table_0').wait_until(&:present?).html
        html = Nokogiri::HTML(html)
        link_id = nil

        html.css('tbody tr').each do |row|
          next unless row.css('td:nth-child(3)').text == action.to_s.upcase

          link_id = row.css('td:nth-child(1) a').attr('id').value
        end

        if link_id.blank?
          browser.window.close
          browser.original_window.use
          browser.goto('https://ssworldtrak.com/WebtrakWTNew/logoff.aspx')
          browser.close

          document_response.error = DocumentNotFoundError.new
          return document_response
        end

        browser.element(css: "##{link_id}").click

        sleep(50) # so Chrome can finish downloading, Selenoid default timeout is 60s

        download_url = "#{selenoid_credential.selenoid_options[:download_url]}/#{browser.driver.session_id}"
        response = HTTPClient.get("#{download_url}/?json")

        filename = URI.encode_www_form_component(JSON.parse(response.body)&.last)
        url = "#{download_url}/#{filename}"

        document_response.request = URI.parse(url)

        begin
          response = HTTPClient.get(url)
        rescue StandardError => e
          document_response.error = e
          return document_response
        end

        browser.window.close
        browser.original_window.use
        browser.goto('https://ssworldtrak.com/WebtrakWTNew/logoff.aspx')
        browser.close

        unless response.code == 200
          document_response.error = DocumentNotFoundError.new

          return document_response
        end

        document_response.assign_attributes(content_type: response.headers['content-type'], data: response.body)
        document_response
      end

      def parse_rate_response(shipment:, response:)
        rate_response = RateResponse.new(request: last_request, response:)

        if response.blank?
          rate_response.error = ResponseError.new('Blank response')
          return rate_response
        end

        error = response.dig(:get_rating_response, :get_rating_result, :rating_output, :message)

        if error.present?
          if error.include?('do not service this lane')
            rate_response.error = UnserviceableError.new(
              'Incorrect ZIP code or no service available at origin and/or destination'
            )
            return rate_response
          end

          pretty_error = error.strip.gsub('can not', 'cannot')

          rate_response.error = ResponseError.new(pretty_error)
          return rate_response
        end

        result = response.dig(:get_rating_response, :get_rating_result, :rating_output)

        if result.blank?
          rate_response.error = ResponseError.new('Blank response')
          return rate_response
        end

        cents = parse_amount(result[:standard_total_rate])

        if cents.blank?
          rate_response.error = ResponseError.new('Cost is blank')
          return rate_response
        end

        prices = []
        prices << Price.new(blame: :api, cents:, description: 'Freight')

        accessorial_outputs = result.dig(:accessorial_output, :accessorial_output)

        accessorial_outputs.each do |accessorial_output|
          prices << Price.new(blame: :api, cents: 0, description: accessorial_output_description(accessorial_output))
        end

        transit_days = response[:transit_days].to_i

        rate = Rate.new(
          carrier: self,
          carrier_name: name,
          currency: 'USD',
          estimate_reference: nil,
          scac:,
          service_name: :standard,
          shipment:,
          prices:,
          transit_days:,
          with_excessive_length_fees: rates_with_excessive_length_fees?
        )

        rate_response.rates = [rate]
        rate_response
      end

      def request_blueprint
        api_credentials = fetch_credential(:api)

        {
          request: {
            Application: 'ThirdParty',
            AccountNumber: api_credentials.account,
            UserID: api_credentials.username,
            Password: api_credentials.password,
            TestMode: 'N'
          }
        }
      end

      # Tracking
    end
  end
end
