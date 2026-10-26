module FreightKit
  module Carriers
    class RoadrunnerTransportationServices < Carrier
      class << self
        def check_mailing_addresses
          [
            Address.new(
              city: 'Chicago',
              country: Countries.find_by(iso31661_alpha2: 'US'),
              id: 'f436b32e-7ae2-4fe8-a8a7-f410d75d9cfc',
              postal_code: '60694',
              region_abbreviation: 'IL',
              street: 'PO Box 74857'
            )
          ]
        end

        def contacts
          [
            Contact.new(
              department: 'Dispatch - Mira Loma, CA',
              id: 'dc14714f-e381-4b8b-97a6-f002c0897409',
              phone: '+19513615900'
            ),
            Contact.new(department: 'Main', id: '22203680-060c-41db-ba65-9925e8fa381d', phone: '+14146151696')
          ]
        end

        def headquarters
          Address.new(
            city: 'Milwaukee',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'a9baff89-6ef0-4c88-9dd5-05c53e355a9c',
            postal_code: '53224',
            region_abbreviation: 'WI',
            street: '9160 N 107th'
          )
        end

        def id = '62f7ca47-7577-4ad0-a54a-e37d2ffa6696'
        def legal_name = 'Roadrunner Transportation Services Inc'

        def mappable_accessorials
          {
            afterhours_delivery: 'NBD',
            airport_delivery: 'AID',
            airport_pickup: 'AIP',
            amusement_park_delivery: 'AMD',
            amusement_park_pickup: 'AMP',
            appointment_delivery: 'APT',
            church_delivery: 'CHD',
            church_pickup: 'CHP',
            construction_delivery: 'CSD',
            construction_pickup: 'CSP',
            farm_delivery: 'FAD',
            farm_pickup: 'FAP',
            golf_course_delivery: 'CCD',
            golf_course_pickup: 'CCP',
            government_delivery: 'GSD',
            grocery_warehouse_delivery: 'GWD',
            grocery_warehouse_pickup: 'GWP',
            hotel_delivery: 'HHD',
            hotel_pickup: 'HHP',
            inside_delivery: 'ID',
            inside_pickup: 'IP',
            jobsite_delivery: 'CSD',
            jobsite_pickup: 'CSP',
            liftgate_delivery: 'LGD',
            liftgate_pickup: 'LGP',
            military_site_delivery: 'GSD',
            mine_site_delivery: 'MSD',
            nursing_home_delivery: 'NHD',
            nursing_home_pickup: 'NHP',
            park_delivery: 'CPD',
            park_pickup: 'CPP',
            prison_delivery: 'PSD',
            ranch_delivery: 'FAD',
            ranch_pickup: 'FAP',
            reservation_delivery: 'IRD',
            reservation_pickup: 'IRP',
            residential_delivery: 'RSD',
            residential_pickup: 'RSP',
            resort_delivery: 'CPD',
            resort_pickup: 'CPP',
            school_delivery: 'SHD',
            school_pickup: 'SHP',
            university_delivery: 'SHD',
            university_pickup: 'SHP',
            storage_facility_delivery: 'STD',
            storage_facility_pickup: 'STP',
            utility_site_delivery: 'USD',
            utility_site_pickup: 'USP'
          }
        end

        def maximum_height = Measured::Length.new(105, :inches)
        def maximum_weight = Measured::Weight.new(10_000, :pounds)
        def minimum_length_for_overlength_fees = Measured::Length.new(8, :feet)
        def name = 'Roadrunner Transportation Services'
        def overlength_fees_require_tariff? = false
        def required_credential_types = %i[website]
        def requirements = %i[credentials]
        def scac = 'RDFS'
        def services = %i[standard]

        def terminals
          [
            Terminal.new(
              address: Address.new(
                city: 'Los Angeles',
                country: Countries.find_by(iso31661_alpha2: 'US'),
                id: '8fcc2577-d11e-4f1b-baf0-eeb092ce78fa',
                postal_code: '90040',
                region_abbreviation: 'CA',
                street: '4501 E Washington Blvd #2'
              ),
              id: '37649eaf-fcb1-4917-993a-cd82099b86ad',
              phone: '+13237803488'
            ),
            Terminal.new(
              address: Address.new(
                city: 'Memphis',
                country: Countries.find_by(iso31661_alpha2: 'US'),
                id: 'ae6dd9b3-46b6-433d-b1d9-ba80cad25ce3',
                postal_code: '38118',
                region_abbreviation: 'TN',
                street: '3845 Crowfarn Dr'
              ),
              id: 'b6d14db7-d645-491f-b205-7b2b0e2d6a95',
              phone: '+19013007860'
            ),
            Terminal.new(
              address: Address.new(
                city: 'Indianapolis',
                country: Countries.find_by(iso31661_alpha2: 'US'),
                id: 'da0296b5-7dba-4e3d-8fb2-cbe9ac368511',
                postal_code: '46241',
                region_abbreviation: 'IN',
                street: '5751 Dividend Rd'
              ),
              id: '56f382aa-cc26-462c-8bcb-0f5de30b190b',
              phone: '+13177918978'
            )
          ]
        end

        def unquotable_accessorials
          %i[
            athletic_facility_delivery
            athletic_facility_pickup
            cemetery_delivery
            cemetery_pickup
            dock_dropoff
            dock_pickup
            fitness_center_delivery
            fitness_center_pickup
            government_pickup
            grocery_store_delivery
            grocery_store_pickup
            hospital_delivery
            hospital_pickup
            inspection_site_delivery
            inspection_site_pickup
            mall_delivery
            mall_pickup
            marina_delivery
            marina_pickup
            military_site_pickup
            mine_site_pickup
            motel_delivery
            motel_pickup
            prison_pickup
            restaurant_delivery
            restaurant_pickup
            steel_mill_delivery
            steel_mill_pickup
          ]
        end

        def unserviceable_accessorials
          %i[
            appointment_pickup
            brewery_delivery
            brewery_pickup
            convention_delivery
            convention_pickup
            customs_brokerage
            driver_assist
            early_morning_delivery
            fair_delivery
            fair_pickup
            flatbed_delivery
            flatbed_pickup
            guaranteed_delivery_am
            guaranteed_delivery_pm
            guaranteed_delivery
            winery_delivery
            winery_pickup
          ]
        end

        def us_dot_number = 242_009
        def us_mc_number = 170_247
        def website_url = 'https://freight.rrts.com'
      end

      include FreightKit::Rateable

      API = {
        actions: { rates: :rate_quote_by_account },
        domains: {
          bol: 'tools.rrts.com',
          pod: 'tools.rrts.com',
          rates: 'webservices.rrts.com',
          track: 'webservices.rrts.com',
          tracking_number_from_pickup_number: 'tools.rrts.com'
        },
        endpoints: {
          bol: '/LTLTrack/Home/ShowImage?proNumber=%%TRACKING_NUMBER%%&imageType=BOL',
          pod: '/LTLTrack/Home/ShowImage?proNumber=%%TRACKING_NUMBER%%&imageType=POD',
          rates: '/rating/ratequote.asmx?wsdl',
          track: '/TrackWebApi/api/values',
          tracking_number_from_pickup_number: '/LTLTrack/?searchValues=%%PICKUP_NUMBER%%'
        },
        soap: { namespaces: { rates: 'https://webservices.rrts.com/ratequote/' } },
        use_ssl: { bol: false, pod: false, rates: false, track: true, tracking_number_from_pickup_number: false }
      }.freeze
      EVENTS = {
        types: {
          arrived_at_terminal: 'ARV',
          delayed_due_to_weather: 'WTR',
          delivered: 'DEL',
          delivery_appointment_scheduled: 'APT',
          departed: 'DSP',
          located: 'ENR',
          out_for_delivery: 'OFD',
          pending_delivery_appointment: 'CFA',
          picked_up: 'PU',
          trailer_closed: 'CLO',
          trailer_unloaded: 'UNL'
        }
      }.freeze

      # Documents

      def find_tracking_info(tracking_number)
        response = commit_tracking_request(tracking_number)

        parse_tracking_response(response)
      end

      def find_tracking_number_from_pickup_number(pickup_number, _date)
        parse_tracking_number_from_pickup_number_response(pickup_number)
      end

      def pod(tracking_number) = parse_document_response(:pod, tracking_number)
      def scanned_bol(tracking_number) = parse_document_response(:bol, tracking_number)

      protected

      def build_rate_request(shipment:)
        api_credential = fetch_credential(:website)
        validate_api_credential!(api_credential)

        service_delivery_options = [
          # API calls this invalid now
          # service_options: { service_code: 'SS' }
        ]

        if shipment.accessorials.present?
          serviceable_accessorials?(shipment.accessorials)

          service_delivery_options = shipment.accessorials.excluding(*unquotable_accessorials).map do |accessorial|
            { service_options: { service_code: mappable_accessorials[accessorial] } }
          end
        end

        shipment.packages.each do |package|
          longest_dimension = [package.width(:inches), package.length(:inches)].max.ceil

          next if longest_dimension < 96

          package.quantity.times do
            if longest_dimension >= 240
              service_delivery_options << { service_options: { service_code: 'EXX' } }
            elsif longest_dimension >= 144
              service_delivery_options << { service_options: { service_code: 'EXL' } }
            elsif longest_dimension >= 96
              service_delivery_options << { service_options: { service_code: 'EXM' } }
            end
          end
        end

        shipment_detail = []
        shipment_box_count = 0
        shipment_pallet_count = 0

        shipment.packages.each do |package|
          if package.packaging.type == 'pallet'
            shipment_pallet_count += package.quantity
          else
            shipment_box_count += package.quantity
          end

          package.quantity.times do
            shipment_detail << { 'ActualClass' => package.freight_class, 'Weight' => package.pounds(:each).ceil }
          end
        end

        cubic_feet = if shipment.packages.map { |package| package.cubic_ft(:each) }.any?(nil)
                       nil
                     else
                       shipment.packages.sum { |package| package.cubic_ft(:total) }.ceil
                     end

        request = {
          'request' => {
            account: api_credential.account,
            cubic_feet:,
            destination_zip: shipment.destination.postal_code.gsub(/\s+/, '').upcase,
            # linear_feet: linear_ft(packages),
            origin_type: 'B', # O for shipper, I for consignee, B for third party
            origin_zip: shipment.origin.postal_code.gsub(/\s+/, '').upcase,
            pallet_count: shipment_pallet_count,
            payment_type: 'P', # prepaid
            pieces: shipment_box_count,
            service_delivery_options:,
            shipment_details: { shipment_detail: }
          }
        }

        save_request(request)
        request
      end

      def build_soap_header(action)
        api_credential = fetch_credential(:website)
        validate_api_credential!(api_credential)

        {
          authentication_header: {
            :@xmlns => API.dig(:soap, :namespaces, action),
            password: api_credential.password,
            user_name: api_credential.username
          }
        }
      end

      def commit(action, request)
        client_args = {
          wsdl: request_url(action),
          convert_request_keys_to: :camelcase,
          env_namespace: :soap,
          element_form_default: :qualified
        }

        call_args = { soap_header: build_soap_header(action), message: request }

        soap_operation = API.dig(:actions, action)

        client = ::FreightKit::SoapClient.new(carrier: self, action:, client_args:, call_args:, soap_operation:)
        client.call(handle_soap_fault_error: false)
      rescue Savon::SOAPFault => e
        invalid_user = e.message.include?('RRTS.Common.BLL.InvalidUserException')
        raise InvalidCredentialsError, 'Invalid credentials' if invalid_user

        error = if e.respond_to?(:to_hash)
                  error_hash = e.to_hash

                  {
                    message: error_hash.dig(:fault, :detail, :error, :error_message),
                    number: error_hash.dig(:fault, :detail, :error, :error_number)
                  }
                else
                  {}
                end

        if error[:message].blank?
          erorr[:message] = if error[:number].present?
                              "Error #{error[:number]}"
                            else
                              'Unknown error'
                            end
        end

        { error: }
      end

      def commit_tracking_request(tracking_number)
        uri = URI.parse("#{request_url(:track)}/#{tracking_number}")
        save_request(uri)

        uri.open
      rescue OpenURI::HTTPError, Errno::EHOSTUNREACH
        nil
      end

      def parse_amount(amount)
        negative = amount.start_with?('-$') || amount.start_with?('-')

        ['$', '-', ','].each do |char|
          amount = amount.sub(char, '')
        end

        return 0 if amount.blank?

        amount = (amount.to_f * 100).to_i
        return amount unless negative

        amount * -1
      end

      def parse_api_date_time(date_time, location)
        return if date_time.blank? || date_time == '0001-01-01T00:00:00'

        local_date_time = ::Time.strptime(date_time, '%Y-%m-%dT%H:%M:%S').to_fs(:db)
        ::FreightKit::DateTime.new(local_date_time:, location:)
      end

      def parse_api_location(comment, delimiters)
        return if comment.blank? || !comment.include?(delimiters[0])

        parts = if delimiters.size == 2
                  comment.split(delimiters[0])[0].split(delimiters[1])[1].split(',')
                else
                  comment.split(delimiters[0])[1].split(',')
                end

        if parts.size == 1
          str = parts[0].downcase
          return Location.new(city: 'Long Beach', province: 'CA', country: ActiveUtils::Country.find('USA')) if str.include?('long beach')

          return
        end

        city = parts[0].squish.strip.titleize
        province = parts[1].gsub('.', '').squish.strip.upcase
        country = ActiveUtils::Country.find('USA')

        Location.new(city:, province:, country:)
      end

      def parse_document_response(type, tracking_number)
        url = request_url(type).sub('%%TRACKING_NUMBER%%', tracking_number.to_s)
        document_response = DocumentResponse.new(request: url)

        begin
          doc = Nokogiri::HTML(URI.parse(url).open)
        rescue OpenURI::HTTPError
          document_response.error = FreightKit::DocumentNotFoundError.new
          return document_response
        end

        if doc.css('img').blank?
          document_response.error = FreightKit::DocumentNotFoundError.new
          return document_response
        end

        data = Base64.decode64(doc.css('img').first['src'].split('data:image/jpg;base64,').last)

        document_response.assign_attributes(content_type: 'image/jpeg', data:)
        document_response
      end

      def parse_rate_response(shipment:, response:)
        rate_response = RateResponse.new(request: last_request, response:)

        error_number = response.dig(:error, :number)&.to_i
        error_message = response.dig(:error, :message)

        if error_number.present?
          case error_number
          when 99_991
            rate_response.error = UnserviceableError.new(error_message)
            return rate_response
          end
        end

        # @todo Don't rely on error_message

        if error_message.present? && error_message.downcase.include?('not in the standard pickup area')
          rate_response.error = UnserviceableError
          return rate_response
        end

        if error_message.present? || error_number.present?
          parts = [error_message]
          parts << "(#{error_number})" if error_number.present?

          message = parts.compact_blank.join(' ')

          rate_response.error = ResponseError.new(message)
          return rate_response
        end

        result = response.dig(:rate_quote_by_account_response, :rate_quote_by_account_result)

        if result[:net_charge].blank?
          rate_response.error = ResponseError.new('Cost is empty')
          return rate_response
        end

        estimate_reference = result[:quote_number]
        rate_details = result.dig(:rate_details, :quote_detail)
        transit_days = result.dig(:routing_info, :estimated_transit_days).to_i

        prices = []

        rate_details.each do |rate_detail|
          if rate_detail[:description].blank?
            prices << Price.new(blame: :api, cents: parse_amount(rate_detail[:charge]), description: 'Freight')

            next
          end

          prices << FreightKit::Price.new(
            blame: :api,
            cents: parse_amount(rate_detail[:charge]),
            description: rate_detail[:description]&.capitalize
          )
        end

        rate = Rate.new(
          carrier: self,
          carrier_name: name,
          currency: 'USD',
          estimate_reference:,
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

      def parse_tracking_number_from_pickup_number_response(pickup_number)
        url = request_url(:tracking_number_from_pickup_number).sub('%%PICKUP_NUMBER%%', pickup_number.to_s)

        begin
          doc = Nokogiri::HTML(URI.parse(url).open)
        rescue OpenURI::HTTPError, Errno::EHOSTUNREACH
          return
        end

        pro = doc.css('#lblProNumber')&.text

        return if pro.blank? || pro.downcase.include?('not available')

        pro
      end

      def parse_tracking_response(response)
        tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)

        json = JSON.parse(response&.read || '{}')

        if json['SearchResults'].blank? || response.status[0] != '200'
          tracking_response.error = ShipmentNotFoundError.new
          return tracking_response
        end

        search_result = json['SearchResults']&.first

        pro = search_result.dig('Shipment', 'ProNumber')&.downcase
        if pro.blank? || pro.downcase.include?('not available')
          tracking_response.error = ShipmentNotFoundError.new
          return tracking_response
        end

        receiver_location = Location.new(
          city: search_result.dig('Shipment', 'Consignee', 'City').titleize,
          province: search_result.dig('Shipment', 'Consignee', 'State').upcase,
          country: ActiveUtils::Country.find('USA')
        )

        shipper_location = Location.new(
          city: search_result.dig('Shipment', 'Origin', 'City').titleize,
          province: search_result.dig('Shipment', 'Origin', 'State').upcase,
          country: ActiveUtils::Country.find('USA')
        )

        api_date_time = search_result.dig('Shipment', 'DeliveredDateTime')
        actual_delivery_date = parse_api_date_time(api_date_time, receiver_location)

        api_date_time = search_result.dig('Shipment', 'ApptDateTime')
        scheduled_delivery_date = parse_api_date_time(api_date_time, receiver_location)

        tracking_number = search_result.dig('Shipment', 'SearchItem')

        api_date_time = search_result.dig('Shipment', 'ProDateTime')
        ship_time = parse_api_date_time(api_date_time, shipper_location)

        last_location = nil
        shipment_events = []

        search_result.dig('Shipment', 'Comments').each do |api_event|
          type_code = api_event['ActivityCode']
          next if !type_code || type_code == 'ARQ'

          event = EVENTS[:types].key(type_code)
          next if event.blank?

          comment = strip_date(api_event['StatusComment'])

          location = case event
                     when :arrived_at_terminal
                       parse_api_location(comment, [' terminal in '])
                     when :delayed_due_to_weather,
                          :delivery_appointment_scheduled,
                          :pending_delivery_appointment,
                          :trailer_closed,
                          :trailer_unloaded
                       last_location
                     when :delivered
                       receiver_location
                     when :departed, :out_for_delivery
                       parse_api_location(comment, [' to ', 'from '])
                     when :located
                       parse_api_location(comment, [' currently at '])
                     when :picked_up
                       shipper_location
                     end

          date_time = parse_api_date_time(api_event['StatusDateTime'], location)

          last_location = location

          shipment_events << ShipmentEvent.new(date_time:, location:, type_code: event)
        end

        status = shipment_events.last&.type_code

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

      def request_url(action)
        scheme = API.dig(:use_ssl, action) ? 'https://' : 'http://'
        "#{scheme}#{API.dig(:domains, action)}#{API.dig(:endpoints, action)}"
      end

      def strip_date(str) = str ? str.split(/[A|P]M /)[1] : nil

      def validate_api_credential!(api_credential)
        %i[account password username].each do |attribute|
          if !api_credential.respond_to?(attribute) || api_credential.public_send(attribute).blank?
            raise InvalidCredentialsError, "Invalid #{attribute}"
          end

          next unless attribute == :account

          # Raises vague input exception from API if we don't handle ourselves
          next if api_credential.account.gsub(/\D/, '') == api_credential.account &&
                  api_credential.account.length >= 6

          raise InvalidCredentialsError, 'Invalid account'
        end
      end
    end
  end
end
