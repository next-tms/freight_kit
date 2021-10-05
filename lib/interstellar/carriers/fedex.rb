module Interstellar

  # FedEx carrier implementation.
  #
  # FedEx module by Jimmy Baker (http://github.com/jimmyebaker)
  # Documentation can be found here: http://images.fedex.com/us/developer/product/WebServices/MyWebHelp/PropDevGuide.pdf
  class FedEx < Carrier
    self.retry_safe = true

    cattr_reader :name
    @@name = "FedEx"

    TEST_URL = 'https://gatewaybeta.fedex.com:443/xml'
    LIVE_URL = 'https://gateway.fedex.com:443/xml'

    CARRIER_CODES = {
      "fedex_ground" => "FDXG",
      "fedex_express" => "FDXE"
    }

    DELIVERY_ADDRESS_NODE_NAMES = %w(DestinationAddress ActualDeliveryAddress)
    SHIPPER_ADDRESS_NODE_NAMES  = %w(ShipperAddress)

    SERVICE_TYPES = {
      "PRIORITY_OVERNIGHT" => "FedEx Priority Overnight",
      "PRIORITY_OVERNIGHT_SATURDAY_DELIVERY" => "FedEx Priority Overnight Saturday Delivery",
      "FEDEX_2_DAY" => "FedEx 2 Day",
      "FEDEX_2_DAY_SATURDAY_DELIVERY" => "FedEx 2 Day Saturday Delivery",
      "STANDARD_OVERNIGHT" => "FedEx Standard Overnight",
      "FIRST_OVERNIGHT" => "FedEx First Overnight",
      "FIRST_OVERNIGHT_SATURDAY_DELIVERY" => "FedEx First Overnight Saturday Delivery",
      "FEDEX_EXPRESS_SAVER" => "FedEx Express Saver",
      "FEDEX_1_DAY_FREIGHT" => "FedEx 1 Day Freight",
      "FEDEX_1_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 1 Day Freight Saturday Delivery",
      "FEDEX_2_DAY_FREIGHT" => "FedEx 2 Day Freight",
      "FEDEX_2_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 2 Day Freight Saturday Delivery",
      "FEDEX_3_DAY_FREIGHT" => "FedEx 3 Day Freight",
      "FEDEX_3_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 3 Day Freight Saturday Delivery",
      "INTERNATIONAL_PRIORITY" => "FedEx International Priority",
      "INTERNATIONAL_PRIORITY_SATURDAY_DELIVERY" => "FedEx International Priority Saturday Delivery",
      "INTERNATIONAL_ECONOMY" => "FedEx International Economy",
      "INTERNATIONAL_FIRST" => "FedEx International First",
      "INTERNATIONAL_PRIORITY_FREIGHT" => "FedEx International Priority Freight",
      "INTERNATIONAL_ECONOMY_FREIGHT" => "FedEx International Economy Freight",
      "GROUND_HOME_DELIVERY" => "FedEx Ground Home Delivery",
      "FEDEX_GROUND" => "FedEx Ground",
      "INTERNATIONAL_GROUND" => "FedEx International Ground",
      "SMART_POST" => "FedEx SmartPost",
      "FEDEX_FREIGHT_PRIORITY" => "FedEx Freight Priority",
      "FEDEX_FREIGHT_ECONOMY" => "FedEx Freight Economy"
    }

    PACKAGE_TYPES = {
      "fedex_envelope" => "FEDEX_ENVELOPE",
      "fedex_pak" => "FEDEX_PAK",
      "fedex_box" => "FEDEX_BOX",
      "fedex_tube" => "FEDEX_TUBE",
      "fedex_10_kg_box" => "FEDEX_10KG_BOX",
      "fedex_25_kg_box" => "FEDEX_25KG_BOX",
      "your_packaging" => "YOUR_PACKAGING"
    }

    DROPOFF_TYPES = {
      'regular_pickup' => 'REGULAR_PICKUP',
      'request_courier' => 'REQUEST_COURIER',
      'dropbox' => 'DROP_BOX',
      'business_service_center' => 'BUSINESS_SERVICE_CENTER',
      'station' => 'STATION'
    }

    SIGNATURE_OPTION_CODES = {
      adult: 'ADULT', # 21 years plus
      direct: 'DIRECT', # A person at the delivery address
      indirect: 'INDIRECT', # A person at the delivery address, or a neighbor, or a signed note for fedex on the door
      none_required: 'NO_SIGNATURE_REQUIRED',
      default_for_service: 'SERVICE_DEFAULT'
    }

    PAYMENT_TYPES = {
      'sender' => 'SENDER',
      'recipient' => 'RECIPIENT',
      'third_party' => 'THIRDPARTY',
      'collect' => 'COLLECT'
    }

    PACKAGE_IDENTIFIER_TYPES = {
      'tracking_number' => 'TRACKING_NUMBER_OR_DOORTAG',
      'door_tag' => 'TRACKING_NUMBER_OR_DOORTAG',
      'rma' => 'RMA',
      'ground_shipment_id' => 'GROUND_SHIPMENT_ID',
      'ground_invoice_number' => 'GROUND_INVOICE_NUMBER',
      'ground_customer_reference' => 'GROUND_CUSTOMER_REFERENCE',
      'ground_po' => 'GROUND_PO',
      'express_reference' => 'EXPRESS_REFERENCE',
      'express_mps_master' => 'EXPRESS_MPS_MASTER',
      'shipper_reference' => 'SHIPPER_REFERENCE',
    }

    TRANSIT_TIMES = %w(UNKNOWN ONE_DAY TWO_DAYS THREE_DAYS FOUR_DAYS FIVE_DAYS SIX_DAYS SEVEN_DAYS EIGHT_DAYS NINE_DAYS TEN_DAYS ELEVEN_DAYS TWELVE_DAYS THIRTEEN_DAYS FOURTEEN_DAYS FIFTEEN_DAYS SIXTEEN_DAYS SEVENTEEN_DAYS EIGHTEEN_DAYS)

    # FedEx tracking codes as described in the FedEx Tracking Service WSDL Guide
    # All delays also have been marked as exceptions
    TRACKING_STATUS_CODES = HashWithIndifferentAccess.new(
      'AA' => :at_airport,
      'AD' => :at_delivery,
      'AF' => :at_fedex_facility,
      'AR' => :at_fedex_facility,
      'AP' => :at_pickup,
      'CA' => :canceled,
      'CH' => :location_changed,
      'DE' => :exception,
      'DL' => :delivered,
      'DP' => :departed_fedex_location,
      'DR' => :vehicle_furnished_not_used,
      'DS' => :vehicle_dispatched,
      'DY' => :exception,
      'EA' => :exception,
      'ED' => :enroute_to_delivery,
      'EO' => :enroute_to_origin_airport,
      'EP' => :enroute_to_pickup,
      'FD' => :at_fedex_destination,
      'HL' => :held_at_location,
      'IT' => :in_transit,
      'LO' => :left_origin,
      'OC' => :order_created,
      'OD' => :out_for_delivery,
      'PF' => :plane_in_flight,
      'PL' => :plane_landed,
      'PU' => :picked_up,
      'RS' => :return_to_shipper,
      'SE' => :exception,
      'SF' => :at_sort_facility,
      'SP' => :split_status,
      'TR' => :transfer
    )

    DEFAULT_LABEL_STOCK_TYPE = 'PAPER_7X4.75'

    # Available return formats for image data when creating labels
    LABEL_FORMATS = %w(DPL EPL2 PDF ZPLII PNG).freeze

    TRANSIENT_TRACK_RESPONSE_CODES = %w(9035 9040 9041 9045 9050 9055 9060 9065 9070 9075 9085 9086 9090).freeze

    UNRECOVERABLE_TRACK_RESPONSE_CODES = %w(9080 9081 9082 9095 9100).freeze

    def self.service_name_for_code(service_code)
      SERVICE_TYPES[service_code] || "FedEx #{service_code.titleize.sub(/Fedex /, '')}"
    end

    def requirements
      [:key, :password, :account, :login]
    end

    def find_rates(origin, destination, packages, options = {})
      options = @options.merge(options)
      packages = Array(packages)

      rate_request = build_rate_request(origin, destination, packages, options)

      xml = commit(save_request(rate_request), (options[:test] || false))

      parse_rate_response(origin, destination, packages, xml, options)
    end

    def find_tracking_info(tracking_number, options = {})
      options = @options.merge(options)

      tracking_request = build_tracking_request(tracking_number, options)
      xml = commit(save_request(tracking_request), (options[:test] || false))
      parse_tracking_response(xml, options)
    end


    # Get Shipping labels
    def create_shipment(origin, destination, packages, options = {})
      options = @options.merge(options)
      packages = Array(packages)
      raise Error, "Multiple packages are not supported yet." if packages.length > 1

      request = build_shipment_request(origin, destination, packages, options)
      logger.debug(request) if logger

      response = commit(save_request(request), (options[:test] || false))
      parse_ship_response(response)
    end

    def maximum_address_field_length
      # See Fedex Developper Guide
      35
    end

    protected

    def build_shipment_request(origin, destination, packages, options = {})
      imperial = location_uses_imperial(origin)

      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.ProcessShipmentRequest(xmlns: 'http://fedex.com/ws/ship/v13') do
          build_request_header(xml)
          build_version_node(xml, 'ship', 13, 0 ,0)

          xml.RequestedShipment do
            xml.ShipTimestamp(ship_timestamp(options[:turn_around_time]).iso8601(0))
            xml.DropoffType('REGULAR_PICKUP')
            xml.ServiceType(options[:service_type] || 'FEDEX_GROUND')
            xml.PackagingType('YOUR_PACKAGING')

            xml.Shipper do
              build_contact_address_nodes(xml, options[:shipper] || origin)
            end

            xml.Recipient do
              build_contact_address_nodes(xml, destination)
            end

            xml.Origin do
              build_contact_address_nodes(xml, origin)
            end

            xml.ShippingChargesPayment do
              xml.PaymentType('SENDER')
              xml.Payor do
                build_shipment_responsible_party_node(xml, options[:shipper] || origin)
              end
            end

            xml.LabelSpecification do
              xml.LabelFormatType('COMMON2D')
              xml.ImageType(options[:label_format] || 'PNG')
              xml.LabelStockType(options[:label_stock_type] || DEFAULT_LABEL_STOCK_TYPE)
            end

            xml.RateRequestTypes('ACCOUNT')

            xml.PackageCount(packages.size)
            packages.each do |package|
              xml.RequestedPackageLineItems do
                xml.GroupPackageCount(1)
                build_package_weight_node(xml, package, imperial)
                build_package_dimensions_node(xml, package, imperial)

                # Reference Numbers
                reference_numbers = Array(package.options[:reference_numbers])
                if reference_numbers.size > 0
                  reference_numbers.each do |reference_number_info|
                    xml.CustomerReferences do
                      xml.CustomerReferenceType(reference_number_info[:type] || "CUSTOMER_REFERENCE")
                      xml.Value(reference_number_info[:value])
                    end
                  end
                end

                xml.SpecialServicesRequested do
                  xml.SpecialServiceTypes("SIGNATURE_OPTION")
                  xml.SignatureOptionDetail do
                    xml.OptionType(SIGNATURE_OPTION_CODES[package.options[:signature_option] || :default_for_service])
                  end
                end
              end
            end
          end
        end
      end
      xml_builder.to_xml
    end

    def build_contact_address_nodes(xml, location)
      xml.Contact do
        xml.PersonName(location.name)
        xml.CompanyName(location.company)
        xml.PhoneNumber(location.phone)
      end
      xml.Address do
        xml.StreetLines(location.address1) if location.address1
        xml.StreetLines(location.address2) if location.address2
        xml.City(location.city) if location.city
        xml.StateOrProvinceCode(location.state)
        xml.PostalCode(location.postal_code)
        xml.CountryCode(location.country_code(:alpha2))
        xml.Residential('true') if location.residential?
      end
    end

    def build_shipment_responsible_party_node(xml, origin)
      xml.ResponsibleParty do
        xml.AccountNumber(@options[:account])
        xml.Contact do
          xml.PersonName(origin.name)
          xml.CompanyName(origin.company)
          xml.PhoneNumber(origin.phone)
        end
      end
    end

    def build_rate_request(origin, destination, packages, options = {})
      imperial = location_uses_imperial(origin)

      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.RateRequest(xmlns: 'http://fedex.com/ws/rate/v13') do
          build_request_header(xml)
          build_version_node(xml, 'crs', 13, 0 ,0)

          # Returns delivery dates
          xml.ReturnTransitAndCommit(true)

          # Returns saturday delivery shipping options when available
          xml.VariableOptions('SATURDAY_DELIVERY') if options[:saturday_delivery]

          xml.RequestedShipment do
            if options[:pickup_date]
              xml.ShipTimestamp(options[:pickup_date].to_time.iso8601(0))
            else
              xml.ShipTimestamp(ship_timestamp(options[:turn_around_time]).iso8601(0))
            end

            freight = has_freight?(options)

            unless freight
              # fedex api wants this up here otherwise request returns an error
              xml.DropoffType(options[:dropoff_type] || 'REGULAR_PICKUP')
              xml.PackagingType(options[:packaging_type] || 'YOUR_PACKAGING')
            end

            build_location_node(xml, 'Shipper', options[:shipper] || origin)
            build_location_node(xml, 'Recipient', destination)
            if options[:shipper] && options[:shipper] != origin
              build_location_node(xml, 'Origin', origin)
            end

            if freight
              freight_options = options[:freight]
              build_shipping_charges_payment_node(xml, freight_options)
              build_freight_shipment_detail_node(xml, freight_options, packages, imperial)
              build_rate_request_types_node(xml)
            else
              xml.SmartPostDetail do
                xml.Indicia(options[:smart_post_indicia] || 'PARCEL_SELECT')
                xml.HubId(options[:smart_post_hub_id] || 5902) # default to LA
              end

              build_rate_request_types_node(xml)
              xml.PackageCount(packages.size)
              build_packages_nodes(xml, packages, imperial)
            end
          end
        end
      end
      xml_builder.to_xml
    end

    def build_packages_nodes(xml, packages, imperial)
      packages.map do |pkg|
        xml.RequestedPackageLineItems do
          xml.GroupPackageCount(1)
          build_package_weight_node(xml, pkg, imperial)
          build_package_dimensions_node(xml, pkg, imperial)
        end
      end
    end

    def build_shipping_charges_payment_node(xml, freight_options)
      xml.ShippingChargesPayment do
        xml.PaymentType(freight_options[:payment_type])
        xml.Payor do
          xml.ResponsibleParty do
            # TODO: case of different freight account numbers?
            xml.AccountNumber(freight_options[:account])
          end
        end
      end
    end

    def build_freight_shipment_detail_node(xml, freight_options, packages, imperial)
      xml.FreightShipmentDetail do
        # TODO: case of different freight account numbers?
        xml.FedExFreightAccountNumber(freight_options[:account])
        build_location_node(xml, 'FedExFreightBillingContactAndAddress', freight_options[:billing_location])
        xml.Role(freight_options[:role])

        packages.each do |pkg|
          xml.LineItems do
            xml.FreightClass(freight_options[:freight_class])
            xml.Packaging(freight_options[:packaging])
            build_package_weight_node(xml, pkg, imperial)
            build_package_dimensions_node(xml, pkg, imperial)
          end
        end
      end
    end

    def has_freight?(options)
      options[:freight] && options[:freight].present?
    end

    def build_package_weight_node(xml, pkg, imperial)
      xml.Weight do
        xml.Units(imperial ? 'LB' : 'KG')
        xml.Value([((imperial ? pkg.lbs : pkg.kgs).to_f * 1000).round / 1000.0, 0.1].max)
      end
    end

    def build_package_dimensions_node(xml, pkg, imperial)
      xml.Dimensions do
        [:length, :width, :height].each do |axis|
          value = ((imperial ? pkg.inches(axis) : pkg.cm(axis)).to_f * 1000).round / 1000.0 # 3 decimals
          xml.public_send(axis.to_s.capitalize, value.ceil)
        end
        xml.Units(imperial ? 'IN' : 'CM')
      end
    end

    def build_rate_request_types_node(xml, type = 'ACCOUNT')
      xml.RateRequestTypes(type)
    end

    def build_tracking_request(tracking_number, options = {})
      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.TrackRequest(xmlns: 'http://fedex.com/ws/track/v7') do
          build_request_header(xml)
          build_version_node(xml, 'trck', 7, 0, 0)

          xml.SelectionDetails do
            xml.PackageIdentifier do
              xml.Type(PACKAGE_IDENTIFIER_TYPES[options[:package_identifier_type] || 'tracking_number'])
              xml.Value(tracking_number)
            end

            xml.ShipDateRangeBegin(options[:ship_date_range_begin])         if options[:ship_date_range_begin]
            xml.ShipDateRangeEnd(options[:ship_date_range_end])             if options[:ship_date_range_end]
            xml.TrackingNumberUniqueIdentifier(options[:unique_identifier]) if options[:unique_identifier]
          end

          xml.ProcessingOptions('INCLUDE_DETAILED_SCANS')
        end
      end
      xml_builder.to_xml
    end

    def build_request_header(xml)
      xml.WebAuthenticationDetail do
        xml.UserCredential do
          xml.Key(@options[:key])
          xml.Password(@options[:password])
        end
      end

      xml.ClientDetail do
        xml.AccountNumber(@options[:account])
        xml.MeterNumber(@options[:login])
      end

      xml.TransactionDetail do
        xml.CustomerTransactionId(@options[:transaction_id] || 'Interstellar') # TODO: Need to do something better with this...
      end
    end

    def build_version_node(xml, service_id, major, intermediate, minor)
      xml.Version do
        xml.ServiceId(service_id)
        xml.Major(major)
        xml.Intermediate(intermediate)
        xml.Minor(minor)
      end
    end

    def build_location_node(xml, name, location)
      xml.public_send(name) do
        xml.Address do
          xml.StreetLines(location.address1) if location.address1
          xml.StreetLines(location.address2) if location.address2
          xml.City(location.city) if location.city
          xml.PostalCode(location.postal_code)
          xml.CountryCode(location.country_code(:alpha2))
          xml.Residential(true) unless location.commercial?
        end
      end
    end

    def parse_rate_response(origin, destination, packages, response, options)
      xml = build_document(response, 'RateReply')

      success = response_success?(xml)
      message = response_message(xml)

      if success
        missing_xml_field = false
        rate_estimates = xml.root.css('> RateReplyDetails').map do |rated_shipment|
          begin
            service_code = rated_shipment.at('ServiceType').text
            is_saturday_delivery = rated_shipment.at('AppliedOptions').try(:text) == 'SATURDAY_DELIVERY'
            service_type = is_saturday_delivery ? "#{service_code}_SATURDAY_DELIVERY" : service_code

            transit_time = rated_shipment.at('TransitTime').text if ["FEDEX_GROUND", "GROUND_HOME_DELIVERY"].include?(service_code)
            max_transit_time = rated_shipment.at('MaximumTransitTime').try(:text) if service_code == "FEDEX_GROUND"

            delivery_timestamp = rated_shipment.at('DeliveryTimestamp').try(:text)
            delivery_range = delivery_range_from(transit_time, max_transit_time, delivery_timestamp, (service_code == "GROUND_HOME_DELIVERY"), options)

            currency = rated_shipment.at('RatedShipmentDetails/ShipmentRateDetail/TotalNetCharge/Currency').text

            RateEstimate.new(origin, destination, @@name,
                 self.class.service_name_for_code(service_type),
                 :service_code => service_code,
                 :total_price => rated_shipment.at('RatedShipmentDetails/ShipmentRateDetail/TotalNetCharge/Amount').text.to_f,
                 :currency => currency,
                 :packages => packages,
                 :delivery_range => delivery_range)
          rescue NoMethodError
            missing_xml_field = true
            nil
          end
        end

        rate_estimates = rate_estimates.compact
        logger.warn("[FedexParseRateError] Some fields where missing in the response: #{response}") if logger && missing_xml_field

        if rate_estimates.empty?
          success = false
          if missing_xml_field
            message = "The response from the carrier contained errors and could not be treated"
          else
            message = "No shipping rates could be found for the destination address" if message.blank?
          end
        end

      else
        rate_estimates = []
      end

      RateResponse.new(success, message, Hash.from_xml(response), :rates => rate_estimates, :xml => response, :request => last_request, :log_xml => options[:log_xml])
    end

    def delivery_range_from(transit_time, max_transit_time, delivery_timestamp, is_home_delivery, options)
      delivery_range = [delivery_timestamp, delivery_timestamp]

      # if there's no delivery timestamp but we do have a transit time, use it
      if delivery_timestamp.blank? && transit_time.present?
        transit_range  = parse_transit_times([transit_time, max_transit_time.presence || transit_time])
        pickup_date = options[:pickup_date] || ship_date(options[:turn_around_time])

        delivery_range = transit_range.map { |days| business_days_from(pickup_date, days, is_home_delivery) }
      end

      delivery_range
    end

    def parse_ship_response(response)
      xml = build_document(response, 'ProcessShipmentReply')
      success = response_success?(xml)
      message = response_message(xml)

      response_info = Hash.from_xml(response)
      tracking_number = xml.css("CompletedPackageDetails TrackingIds TrackingNumber").text
      base_64_image = xml.css("Label Image").text

      labels = [Label.new(tracking_number, Base64.decode64(base_64_image))]
      LabelResponse.new(success, message, response_info, {labels: labels})
    end

    def business_days_from(date, days, is_home_delivery=false)
      future_date = date
      count       = 0

      while count < days
        future_date += 1.day
        if is_home_delivery
          count += 1 if home_delivery_business_day?(future_date)
        else
          count += 1 if business_day?(future_date)
        end
      end

      future_date
    end

    #Transit times for FedEx® Ground do not include Saturdays, Sundays, or holidays.
    def business_day?(date)
      (1..5).include?(date.wday)
    end

    #Transit times for FedEx® Home Delivery, do not include Sundays, Mondays, or holidays.
    def home_delivery_business_day?(date)
      (2..6).include?(date.wday)
    end

    def parse_tracking_response(response, options)
      xml = build_document(response, 'TrackReply')

      success = response_success?(xml)
      message = response_message(xml)

      if success
        tracking_details_root = xml.at('CompletedTrackDetails')
        success = response_success?(tracking_details_root)
        message = response_message(tracking_details_root)
      end

      if success
        delivery_signature = nil
        shipment_events = []

        all_tracking_details = xml.root.xpath('CompletedTrackDetails/TrackDetails')
        tracking_details = case all_tracking_details.length
          when 1
            all_tracking_details.first
          when 0
            message = "The response did not contain tracking details"
            return TrackingResponse.new(
              false,
              message,
              Hash.from_xml(response),
              carrier: @@name,
              xml: response,
              request: last_request
            )
          else
            all_unique_identifiers = xml.root.xpath('CompletedTrackDetails/TrackDetails/TrackingNumberUniqueIdentifier').map(&:text)
            message = "Multiple matches were found. Specify a unqiue identifier: #{all_unique_identifiers.join(', ')}"
            return TrackingResponse.new(
              false,
              message,
              Hash.from_xml(response),
              carrier: @@name,
              xml: response,
              request: last_request
            )
        end

        first_notification = tracking_details.at('Notification')
        severity = first_notification.at('Severity').text
        if severity == 'ERROR' || severity == 'FAILURE'
          message = first_notification.try(:text)
          code = first_notification.at('Code').try(:text)
          case code
          when *TRANSIENT_TRACK_RESPONSE_CODES
            raise Interstellar::ShipmentNotFound, first_notification.at('Message').text
          else
            raise Interstellar::ResponseContentError, StandardError.new(first_notification.at('Message').text)
          end
        end

        tracking_number = tracking_details.at('TrackingNumber').text
        status_detail = tracking_details.at('StatusDetail')
        if status_detail.blank?
          status_code, status, status_description, delivery_signature = nil
        else
          status_code = status_detail.at('Code').try(:text)
          status_description = status_detail.at('AncillaryDetails/ReasonDescription').try(:text) || status_detail.at('Description').try(:text)

          status = TRACKING_STATUS_CODES[status_code]

          if status_code == 'DL' && tracking_details.at('AvailableImages').try(:text) == 'SIGNATURE_PROOF_OF_DELIVERY'
            delivery_signature = tracking_details.at('DeliverySignatureName').try(:text)
          end
        end

        origin = if origin_node = tracking_details.at('OriginLocationAddress')
          Location.new(
            country: origin_node.at('CountryCode').text,
            province: origin_node.at('StateOrProvinceCode').text,
            city: origin_node.at('City').text
          )
        end

        destination = extract_address(tracking_details, DELIVERY_ADDRESS_NODE_NAMES)
        shipper_address = extract_address(tracking_details, SHIPPER_ADDRESS_NODE_NAMES)

        ship_time = extract_timestamp(tracking_details, 'ShipTimestamp')
        actual_delivery_time = extract_timestamp(tracking_details, 'ActualDeliveryTimestamp')
        scheduled_delivery_time = extract_timestamp(tracking_details, 'EstimatedDeliveryTimestamp')

        tracking_details.xpath('Events').each do |event|
          address  = event.at('Address')
          next if address.nil? || address.at('CountryCode').nil?

          city     = address.at('City').try(:text)
          state    = address.at('StateOrProvinceCode').try(:text)
          zip_code = address.at('PostalCode').try(:text)
          country  = address.at('CountryCode').try(:text)

          location = Location.new(:city => city, :state => state, :postal_code => zip_code, :country => country)
          description = event.at('EventDescription').text
          type_code = event.at('EventType').text

          time          = Time.parse(event.at('Timestamp').text)
          zoneless_time = time.utc

          shipment_events << ShipmentEvent.new(description, zoneless_time, location, description, type_code)
        end

        shipment_events = shipment_events.sort_by(&:time)
      end

      TrackingResponse.new(
        success,
        message,
        Hash.from_xml(response),
        carrier: @@name,
        xml: response,
        request: last_request,
        status: status,
        status_code: status_code,
        status_description: status_description,
        ship_time: ship_time,
        scheduled_delivery_date: scheduled_delivery_time,
        actual_delivery_date: actual_delivery_time,
        delivery_signature: delivery_signature,
        shipment_events: shipment_events,
        shipper_address: (shipper_address.nil? || shipper_address.unknown?) ? nil : shipper_address,
        origin: origin,
        destination: destination,
        tracking_number: tracking_number
      )
    end

    def ship_timestamp(delay_in_hours)
      delay_in_hours ||= 0
      Time.now + delay_in_hours.hours
    end

    def ship_date(delay_in_hours)
      delay_in_hours ||= 0
      (Time.now + delay_in_hours.hours).to_date
    end

    def response_success?(document)
      highest_severity = document.at('HighestSeverity')
      return false if highest_severity.nil?
      %w(SUCCESS WARNING NOTE).include?(highest_severity.text)
    end

    def response_message(document)
      notifications = document.at('Notifications')
      return "" if notifications.nil?

      "#{notifications.at('Severity').text} - #{notifications.at('Code').text}: #{notifications.at('Message').text}"
    end

    def commit(request, test = false)
      ssl_post(test ? TEST_URL : LIVE_URL, request.gsub("\n", ''))
    end

    def parse_transit_times(times)
      results = []
      times.each do |day_count|
        days = TRANSIT_TIMES.index(day_count.to_s.chomp)
        results << days.to_i
      end
      results
    end

    def extract_address(document, possible_node_names)
      node = nil
      args = {}
      possible_node_names.each do |name|
        node = document.at(name)
        break if node
      end

      if node
        args[:country] =
          node.at('CountryCode').try(:text) ||
          ActiveUtils::Country.new(:alpha2 => 'ZZ', :name => 'Unknown or Invalid Territory', :alpha3 => 'ZZZ', :numeric => '999')

        args[:province] = node.at('StateOrProvinceCode').try(:text) || 'unknown'
        args[:city] = node.at('City').try(:text) || 'unknown'
      end

      Location.new(args)
    end

    def extract_timestamp(document, node_name)
      if timestamp_node = document.at(node_name)
        if timestamp_node.text =~ /\A(\d{4}-\d{2}-\d{2})T00:00:00\Z/
          Date.parse($1)
        else
          Time.parse(timestamp_node.text)
        end
      end
    end

    def build_document(xml, expected_root_tag)
      document = Nokogiri.XML(xml) { |config| config.strict }
      document.remove_namespaces!
      if document.root.nil? || document.root.name != expected_root_tag
        raise Interstellar::ResponseContentError.new(StandardError.new('Invalid document'), xml)
      end
      document
    rescue Nokogiri::XML::SyntaxError => e
      raise Interstellar::ResponseContentError.new(e, xml)
    end

    def location_uses_imperial(location)
      %w(US LR MM).include?(location.country_code(:alpha2))
    end
  end
end
