module ActiveMerchant
  module Shipping
    class UPS < Carrier
      self.retry_safe = true

      cattr_accessor :default_options
      cattr_reader :name
      @@name = "UPS"

      TEST_URL = 'https://wwwcie.ups.com'
      LIVE_URL = 'https://onlinetools.ups.com'

      RESOURCES = {
        :rates => 'ups.app/xml/Rate',
        :track => 'ups.app/xml/Track',
        :shipment_confirm => 'ups.app/xml/ShipConfirm',
        :shipment_accept => 'ups.app/xml/ShipAccept',
        :void_shipment => 'ups.app/xml/Void',
        :time_in_transit => 'ups.app/xml/TimeInTransit',
        :xav => 'ups.app/xml/XAV'
      }

      PICKUP_CODES = {
        :daily_pickup => "01",
        :customer_counter => "03",
        :one_time_pickup => "06",
        :on_call_air => "07",
        :suggested_retail_rates => "11",
        :letter_center => "19",
        :air_service_center => "20"
      }

      DEFAULT_SERVICES = {
        "01" => "UPS Next Day Air",
        "02" => "UPS Second Day Air",
        "03" => "UPS Ground",
        "07" => "UPS Worldwide Express",
        "08" => "UPS Worldwide Expedited",
        "11" => "UPS Standard",
        "12" => "UPS Three-Day Select",
        "13" => "UPS Next Day Air Saver",
        "14" => "UPS Next Day Air Early A.M.",
        "54" => "UPS Worldwide Express Plus",
        "59" => "UPS Second Day Air A.M.",
        "65" => "UPS Saver",
        "82" => "UPS Today Standard",
        "83" => "UPS Today Dedicated Courier",
        "84" => "UPS Today Intercity",
        "85" => "UPS Today Express",
        "86" => "UPS Today Express Saver",
        "92" => "UPS SurePost Less than 1lb",
        "93" => "UPS SurePost Greater than 1lb",
        "94" => "UPS SurePost BPM",
        "95" => "UPS SurePost Media",
        "M2" => "UPS First-Class Mail",
        "M3" => "UPS Priority Mail",
        "M4" => "UPS Expedited Mail Innovations",
        "M5" => "UPS Priority Mail Innovations",
        "M6" => "UPS Economy Mail Innovations"
      }

      CANADA_ORIGIN_SERVICES = {
        "01" => "UPS Express",
        "02" => "UPS Expedited",
        "14" => "UPS Express Early A.M."
      }

      MEXICO_ORIGIN_SERVICES = {
        "07" => "UPS Express",
        "08" => "UPS Expedited",
        "54" => "UPS Express Plus"
      }

      EU_ORIGIN_SERVICES = {
        "07" => "UPS Express",
        "08" => "UPS Expedited"
      }

      OTHER_NON_US_ORIGIN_SERVICES = {
        "07" => "UPS Express"
      }

      TIME_IN_TRANSIT_US_ORIGIN_CODES = {
        "1DM"  => "14",
        "1DA"  => "01",
        "1DP"  => "13",
        "2DM"  => "59",
        "2DA"  => "02",
        "3DS"  => "12",
        "GND"  => "03",
        "1DMS" => "14", # Saturday Delivery is same code with accessorial option
        "1DAS" => "01", # Saturday Delivery is same code with accessorial option
        "2DAS" => "01", # Saturday Delivery is same code with accessorial option
        "21"   => "54",
        "01"   => "07",
        "28"   => "65",
        "05"   => "08",
        "03"   => "11",
      }

      # From http://en.wikipedia.org/w/index.php?title=European_Union&oldid=174718707 (Current as of November 30, 2007)
      EU_COUNTRY_CODES = ["GB", "AT", "BE", "BG", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE"]

      UPS_EVENT_CODES = {
        'I'  => 'AR',
        'D'  => 'DL',
        'X'  => 'DE',
        'P'  => 'AR',
        'M'  => 'OC'
      }

      PACKAGE_DELIVERY_CONFIRMATION_CODES = {
        delivery_confirmation: 1,
        delivery_confirmation_signature_required: 2,
        delivery_confirmation_adult_signature_required: 3,
        usps_delivery_confirmation: 4
      }

      def requirements
        [:key, :login, :password]
      end

      def find_rates(origin, destination, packages, options={})
        options.update(@options)
        packages = Array(packages)
        access_request = build_access_request
        rate_request = build_rate_request(origin, destination, packages, options)

        File.open('/tmp/ups-request.xml', 'wb'){|f| f << rate_request}
        response = commit(:rates, save_request(access_request + rate_request))
        File.open('/tmp/ups-response.xml', 'wb'){|f| f << response}

        parse_rate_response(origin, destination, packages, response, options)
      end

      def find_tracking_info(tracking_number, options={})
        options.update(@options)
        access_request = build_access_request
        tracking_request = build_tracking_request(tracking_number, options)
        response = commit(:track, save_request(access_request + tracking_request))
        parse_tracking_response(response, options)
      end

      def find_time_in_transit(shipper, origin, destination, packages, options={})
        options.update(@options)
        packages = Array(packages)
        shipment = Shipment.new(
          :shipper           => shipper,
          :payer             => (options[:payer] || shipper),
          :origin            => origin,
          :destination       => destination,
          :packages          => packages,
          :number            => options[:shipment_number],
          :value             => options[:value],
          :service           => (options[:service] || '03'),
          :require_signature => (options[:require_signature] || false)
        )

        access_request = build_access_request
        time_in_transit_request = build_time_in_transit_request(shipment)
        File.open('/tmp/ups-request.xml', 'wb'){|f| f << time_in_transit_request }
        response = commit(:time_in_transit, save_request(access_request + time_in_transit_request))
        File.open('/tmp/ups-response.xml', 'wb'){|f| f << response }
        parse_time_in_transit_response(origin, shipment, response)
      end

      def validate_shipment(shipper, origin, destination, packages, options = {})
        options.update(@options)
        shipment = Shipment.new(
          :shipper           => shipper,
          :payer             => (options[:payer] || shipper),
          :origin            => origin,
          :destination       => destination,
          :packages          => packages,
          :number            => options[:shipment_number],
          :value             => options[:value],
          :service           => (options[:service] || '03'),
          :return_detail     => options[:return_detail],
          :require_signature => (options[:require_signature] || false)
        )

        case shipment.service
        when '92'
          shipment.usps_endorsement = ['1', '3'].include?(options[:endorsement]) ?
                                      options[:endorsement] :
                                      nil
        when '93'
          shipment.usps_endorsement = ['1', '2', '3', '4'].include?(options[:endorsement]) ?
                                      options[:endorsement] :
                                      nil
        end

        expected_price = options[:expected_price]
        price_epsilon = options[:price_epsilon] || Money.new(0)
        request = build_shipment_confirm_request(shipment, options)

        File.open('/tmp/ups-request.xml', 'wb'){|f| f << request }
        shipment.log(request)
        response = commit(:shipment_confirm, save_request(build_access_request + request))
        shipment.log(response)
        File.open('/tmp/ups-response.xml', 'wb'){|f| f << response }

        parse_shipment_confirm(shipment, response)
        # VJ - Change the semantics to return the shipment to have access to the original error.
        shipment
      end

      def validate_address(address, options={})
        options.update(@options)
        request = build_address_validation_request(address, options)
        response = commit(:xav, save_request(build_access_request + request))
        validation = parse_validate_address_response(response, options)
        validation.log = [request, response]
        validation.original = address
        validation
      rescue ActiveMerchant::Shipping::ResponseError => error
        error.log = [request, error.message]
        raise error
      end

      def buy_shipping_labels(shipper, origin, destination, packages, options = {})
        options.update(@options)
        shipment = Shipment.new(
          :shipper => shipper,
          :payer => (options[:payer] || shipper),
          :origin => origin,
          :destination => destination,
          :packages => packages,
          :number => options[:shipment_number],
          :value => options[:value],
          :service => (options[:service] || '03'),
          :return_detail => options[:return_detail],
          :require_signature => (options[:require_signature] || false)
        )
        expected_price = options[:expected_price]
        price_epsilon = options[:price_epsilon] || Money.new(0)

        request = build_shipment_confirm_request(shipment, options)

        File.open('/tmp/ups-request.xml', 'wb'){|f| f << request }
        shipment.log(request)
        response = commit(:shipment_confirm, save_request(build_access_request + request))
        shipment.log(response)

        File.open('/tmp/ups-response.xml', 'wb'){|f| f << response }
        parse_shipment_confirm(shipment, response)

        # TODO should probably raise if this is false since the return value is useless
        if shipment.price && (!expected_price || (shipment.price - expected_price) < price_epsilon)
          request = build_shipment_accept_request(shipment, options)
          File.open('/tmp/ups-request.xml', 'wb'){|f| f << request }
          shipment.log(request)
          response = commit(:shipment_accept, save_request(build_access_request + request))
          shipment.log(response)
          File.open('/tmp/ups-response.xml', 'wb'){|f| f << response }
          parse_shipment_accept(shipment, response)
        end
        shipment
      end

      def cancel_shipment(shipment, options = {})
        options.update(@options)
        request = build_void_shipment_request(shipment)
        shipment.log(request)
        response = commit(:void_shipment, save_request(build_access_request + request))
        shipment.log(response)
        parse_void_shipment(shipment, response)
        shipment
      end

      def return_package(shipper, origin, destination, packages, opts = {})
        opts = opts.merge(return_detail: {return_service_code: '9'}) # '9' - ‘9’ = UPS Print Return Label (PRL)
        buy_shipping_labels(shipper, origin, destination, packages, opts)
      end

      protected

      def build_access_request
        xml_request = XmlNode.new('AccessRequest') do |access_request|
          access_request << XmlNode.new('AccessLicenseNumber', @options[:key])
          access_request << XmlNode.new('UserId', @options[:login])
          access_request << XmlNode.new('Password', @options[:password])
        end
        xml_request.to_xml
      end

      def build_rate_request(origin, destination, packages, options={})
        packages = Array(packages)
        xml_request = XmlNode.new('RatingServiceSelectionRequest') do |root_node|
          root_node << XmlNode.new('Request') do |request|
            request << XmlNode.new('RequestAction', 'Rate')
            request << XmlNode.new('RequestOption', ((options[:service].nil? or options[:service] == :all) ? 'Shop' : 'Rate'))
          end
          root_node << XmlNode.new('PickupType') do |pickup_type|
            pickup_type << XmlNode.new('Code', PICKUP_CODES[options[:pickup_type] || :daily_pickup])
            # not implemented: PickupType/PickupDetails element
          end
          # not implemented: CustomerClassification element
          root_node << XmlNode.new('Shipment') do |shipment|
            # not implemented: Shipment/Description element
            shipment << build_location_node('Shipper', (options[:shipper] || origin), options)
            shipment << build_location_node('ShipTo', destination, options)
            if options[:shipper] and options[:shipper] != origin
              shipment << build_location_node('ShipFrom', origin, options)
            end

            # not implemented:  * Shipment/ShipmentWeight element
            #                   * Shipment/ReferenceNumber element
            #                   * Shipment/Service element
            #                   * Shipment/PickupDate element
            #                   * Shipment/ScheduledDeliveryDate element
            #                   * Shipment/ScheduledDeliveryTime element
            #                   * Shipment/AlternateDeliveryTime element
            #                   * Shipment/DocumentsOnly element

            if options[:service]
              shipment << XmlNode.new('Service') do |service|
                service << XmlNode.new('Code', options[:service])
              end
            end

            packages.each do |package|
              # debugger if package.nil?
              shipment << build_package_node(package, origin, options[:service])
            end

            shipment << XmlNode.new('RateInformation') do |rate_information|
              rate_information << XmlNode.new('NegotiatedRatesIndicator')
            end

            # not implemented:  * Shipment/ShipmentServiceOptions element
            #                   * Shipment/RateInformation element

          end

        end
        xml_request.to_xml
      end

      def build_tracking_request(tracking_number, options={})
        xml_request = XmlNode.new('TrackRequest') do |root_node|
          root_node << XmlNode.new('Request') do |request|
            request << XmlNode.new('RequestAction', 'Track')
            request << XmlNode.new('RequestOption', (options[:includes_signature] ? '9' : '1'))
          end
          root_node << XmlNode.new('TrackingNumber', tracking_number.to_s)
        end
        xml_request.to_xml
      end

      def build_location_node(name,location,options={})
        # not implemented:  * Shipment/Shipper/Name element
        #                   * Shipment/(ShipTo|ShipFrom)/CompanyName element
        #                   * Shipment/(Shipper|ShipTo|ShipFrom)/AttentionName element
        #                   * Shipment/(Shipper|ShipTo|ShipFrom)/TaxIdentificationNumber element
        location_node = XmlNode.new(name) do |location_node|
          unless location.name.blank?
            #node_name = (name == 'Shipper' ? 'Name' : 'CompanyName')
            node_name = 'Name'
            location_node << XmlNode.new(node_name, location.name)
            #if node_name == 'CompanyName' && !location.attention.blank?
            #  location_node << XmlNode.new('AttentionName', location.attention)
            #end
          end
          location_node << XmlNode.new('PhoneNumber', location.phone.gsub(/[^\d]/,'')) unless location.phone.blank?
          location_node << XmlNode.new('FaxNumber', location.fax.gsub(/[^\d]/,'')) unless location.fax.blank?

          if name == 'Shipper' and (origin_account = @options[:origin_account] || options[:origin_account] || @options[:account_id])
            location_node << XmlNode.new('ShipperNumber', origin_account)
          elsif name == 'ShipTo' and (destination_account = @options[:destination_account] || options[:destination_account])
            location_node << XmlNode.new('ShipperAssignedIdentificationNumber', destination_account)
          end

          location_node << XmlNode.new('Address') do |address|
            address << XmlNode.new("AddressLine1", location.address1) unless location.address1.blank?
            address << XmlNode.new("AddressLine2", location.address2) unless location.address2.blank?
            address << XmlNode.new("AddressLine3", location.address3) unless location.address3.blank?
            address << XmlNode.new("City", location.city) unless location.city.blank?
            address << XmlNode.new("StateProvinceCode", location.province) unless location.province.blank?
              # StateProvinceCode required for negotiated rates but not otherwise, for some reason
            address << XmlNode.new("PostalCode", location.postal_code) unless location.postal_code.blank?
            address << XmlNode.new("CountryCode", location.country_code(:alpha2)) unless location.country_code(:alpha2).blank?
            address << XmlNode.new("ResidentialAddressIndicator", 'Y') unless location.commercial? || name == 'Shipper' # the default should be that UPS returns residential rates for destinations that it doesn't know about
            # not implemented: Shipment/(Shipper|ShipTo|ShipFrom)/Address/ResidentialAddressIndicator element
          end
        end
      end

      def build_package_node(package, origin, service = nil)
        imperial = imperial? origin

        XmlNode.new("Package") do |package_node|

          # not implemented:  * Shipment/Package/PackagingType element
          #                   * Shipment/Package/Description element

          package_node << XmlNode.new("PackagingType") do |packaging_type|
            packaging_type << XmlNode.new("Code", '02')
          end

          package_node << XmlNode.new("Dimensions") do |dimensions|
            dimensions << XmlNode.new("UnitOfMeasurement") do |units|
              units << XmlNode.new("Code", imperial ? 'IN' : 'CM')
            end
            [:length,:width,:height].each do |axis|
              value = ((imperial ? package.inches(axis) : package.cm(axis)).to_f*1000).round/1000.0 # 3 decimals
              dimensions << XmlNode.new(axis.to_s.capitalize, [value,0.1].max)
            end
          end

          package_node << XmlNode.new("PackageWeight") do |package_weight|
            unit = weight_unit(origin, service)

            package_weight << XmlNode.new("UnitOfMeasurement") do |units|
              units << XmlNode.new("Code", unit)
            end

            value = weight_sig_fig(package.send(unit.downcase.to_sym), service)

            package_weight << XmlNode.new("Weight", [value, 0.1].max)
          end

          if package.insured_value
            package_node << XmlNode.new("PackageServiceOptions") do |service_options|
              service_options << XmlNode.new("InsuredValue") do |insured_value|
                insured_value << XmlNode.new("CurrencyCode", package.insured_value.currency)
                insured_value << XmlNode.new("MonetaryValue", package.insured_value.cents.to_f / 100)
              end
            end
          end


          # not implemented:  * Shipment/Package/LargePackageIndicator element
          #                   * Shipment/Package/ReferenceNumber element
          #                   * Shipment/Package/PackageServiceOptions element
          #                   * Shipment/Package/AdditionalHandling element
        end
      end

      def parse_rate_response(origin, destination, packages, response, options={})
        rates = []

        xml = REXML::Document.new(response)
        success = response_success?(xml)
        message = response_message(xml)

        if success
          rate_estimates = []

          xml.elements.each('/*/RatedShipment') do |rated_shipment|
            service_code = rated_shipment.get_text('Service/Code').to_s

            total_price = rated_shipment.get_text('TotalCharges/MonetaryValue').to_s.to_f
            currency = rated_shipment.get_text('TotalCharges/CurrencyCode').to_s

            if (val = rated_shipment.get_text('NegotiatedRates/NetSummaryCharges/GrandTotal/MonetaryValue'))
              total_price = val.to_s.to_f
              currency = rated_shipment.get_text('NegotiatedRates/NetSummaryCharges/GrandTotal/CurrencyCode')
            end

            rate_estimates << RateEstimate.new(origin, destination, @@name,
                                service_name_for(origin, service_code),
                                :total_price => total_price,
                                :currency => currency,
                                :service_code => service_code,
                                :packages => packages)
          end
        else
          raise ActiveMerchant::Shipping::ResponseError, response_error_message(xml)
        end
        RateResponse.new(success, message, {}, rates: rate_estimates)
      end

      def parse_tracking_response(response, options={})
        xml = REXML::Document.new(response)
        success = response_success?(xml)
        message = response_message(xml)

        if success
          tracking_number, origin, destination, signed_by, signature = nil
          shipment_events = []

          first_shipment = xml.elements['/*/Shipment']
          first_package = first_shipment.elements['Package']
          tracking_number = first_shipment.get_text('ShipmentIdentificationNumber | Package/TrackingNumber').to_s

          origin, destination = %w{Shipper ShipTo}.map do |location|
            location_from_address_node(first_shipment.elements["#{location}/Address"])
          end

          activities = first_package.get_elements('Activity')
          unless activities.empty?
            delivered_activity = nil
            shipment_events = activities.map do |activity|
              status_type_code = activity.get_text('Status/StatusType/Code').to_s
              description = activity.get_text('Status/StatusType/Description').to_s
              zoneless_time = if (time = activity.get_text('Time')) &&
                                 (date = activity.get_text('Date'))
                time, date = time.to_s, date.to_s
                hour, minute, second = time.scan(/\d{2}/)
                year, month, day = date[0..3], date[4..5], date[6..7]
                Time.utc(year, month, day, hour, minute, second)
              end
              location = location_from_address_node(activity.elements['ActivityLocation/Address'])
              status_type_code = UPS_EVENT_CODES[status_type_code] || 'DL'
              delivered_activity = activity if status_type_code == 'DL'
              ShipmentEvent.new(status_type_code, description, zoneless_time, location)
            end

            shipment_events = shipment_events.sort_by(&:time)

            if origin
              first_event = shipment_events[0]
              same_country = origin.country_code(:alpha2) == first_event.location.country_code(:alpha2)
              same_or_blank_city = first_event.location.city.blank? or first_event.location.city == origin.city
              origin_event = ShipmentEvent.new(first_event.type, first_event.name, first_event.time, origin)
              if same_country and same_or_blank_city
                shipment_events[0] = origin_event
              else
                shipment_events.unshift(origin_event)
              end
            end
            if shipment_events.last.name.downcase == 'delivered'
              if options[:signature_tracking]
                signed_by = delivered_activity.get_text('ActivityLocation/SignedForByName').to_s
                delivery_signature = delivered_activity.get_text('Document/Content').to_s
              end
              shipment_events[-1] = ShipmentEvent.new(shipment_events.last.type, shipment_events.last.name, shipment_events.last.time, destination)
            end
          end
        end
        TrackingResponse.new(success, message, Hash.from_xml(response).values.first,
          :xml => response,
          :request => last_request,
          :shipment_events => shipment_events,
          :origin => origin,
          :destination => destination,
          :tracking_number => tracking_number,
          :signed_by => signed_by,
          :delivery_signature => delivery_signature)
      end

      def location_from_address_node(address)
        return nil unless address
        Location.new(
                :country =>     node_text_or_nil(address.elements['CountryCode']),
                :postal_code => node_text_or_nil(address.elements['PostalCode']),
                :province =>    node_text_or_nil(address.elements['StateProvinceCode']),
                :city =>        node_text_or_nil(address.elements['City']),
                :address1 =>    node_text_or_nil(address.elements['AddressLine1']),
                :address2 =>    node_text_or_nil(address.elements['AddressLine2']),
                :address3 =>    node_text_or_nil(address.elements['AddressLine3'])
              )
      end

      def response_success?(xml)
        xml.get_text('/*/Response/ResponseStatusCode').to_s == '1'
      end

      def response_message(xml)
        xml.get_text('/*/Response/ResponseStatusDescription | /*/Response/Error/ErrorDescription').to_s
      end

      def response_error_message(xml)
        "#{xml.get_text('/*/Response/Error/ErrorCode')} - #{xml.get_text('/*/Response/Error/ErrorDescription')}"
      end

      def commit(action, request)
        url = "#{test_mode ? TEST_URL : LIVE_URL}/#{RESOURCES[action]}"
        response = ssl_post(url, request)
        if (action == :shipment_accept)
          log_external_api_call(url, 'Request Not logged', 'Response Not logged')
        elsif (action == :shipment_confirm)
          log_external_api_call(url, request, 'Response Not logged')
        else
          log_external_api_call(url, request, response)
        end
        response
      end

      def time_in_transit_service_name_for(origin, code)
        # NON-US codes not currently supported. See UPS Time in Transit docs, Appendix D - Service Codes
        service_name_for(origin, TIME_IN_TRANSIT_US_ORIGIN_CODES[code])
      end

      def service_name_for(origin, code)
        origin = origin.country_code(:alpha2)

        name = case origin
        when "CA" then CANADA_ORIGIN_SERVICES[code]
        when "MX" then MEXICO_ORIGIN_SERVICES[code]
        when *EU_COUNTRY_CODES then EU_ORIGIN_SERVICES[code]
        end

        name ||= OTHER_NON_US_ORIGIN_SERVICES[code] unless name == 'US'
        name ||= DEFAULT_SERVICES[code]
      end

      ### NEW

      def build_shipment_confirm_request(shipment, options={})
        xml = Builder::XmlMarkup.new
        xml.instruct!

        xml.ShipmentConfirmRequest do
          xml.Request do
            xml.RequestAction 'ShipConfirm'
            xml.RequestOption 'validate'
            add_reference(xml, shipment)
          end

          xml.LabelSpecification do
            image_format = options[:image_format] || 'ZPL'
            xml.LabelPrintMethod { xml.Code image_format }
            xml.LabelImageFormat { xml.Code image_format }
            xml.LabelStockSize do
              label_height, label_width = options[:label_size] ? options[:label_size].split('x') : [4,6]
              xml.Height label_height
              xml.Width  label_width
            end
          end

          xml.Shipment do
            if shipment.mail_innovations?
              xml.USPSEndorsement '5' # No Service Selected
              xml.CostCenter options[:cost_center]
              xml.PackageID options[:package_id]
            end

            if shipment.return?
              xml.ReturnService { xml.Code options[:return_detail][:return_service_code] }
            end

            xml.RateInformation do
              xml.NegotiatedRatesIndicator
            end

            add_location(xml, 'Shipper', shipment.shipper, options, shipment.international?)
            add_location(xml, 'ShipTo', shipment.destination, options, shipment.international?)

            if shipment.international?
              add_location(xml, 'SoldTo', shipment.destination, options, shipment.international?)
            end

            add_location(xml, 'ShipFrom', shipment.origin, options)

            xml.PaymentInformation do
              if options[:bill_third_party]
                xml.BillThirdParty do
                  xml.BillThirdPartyShipper do
                    xml.AccountNumber(options[:third_party_account_id])
                    xml.ThirdParty do
                      xml.Address do
                        xml.PostalCode(options[:billing_zip])
                        xml.CountryCode(options[:billing_country])
                      end
                    end
                  end
                end
              else
                xml.Prepaid do
                  xml.BillShipper do
                    xml.AccountNumber options[:account_id]
                  end
                end
              end
            end

            xml.Service { xml.Code shipment.service }

            if shipment.surepost?
              xml.SurePostShipment do
                xml.USPSEndorsement shipment.usps_endorsement unless shipment.usps_endorsement.nil?

                if shipment.surepost_under_1?
                  xml.SubClassification shipment.packages.first.subclassification
                end
              end
            end

            if shipment.value and (shipment.destination.country_code(:alpha2) == 'CA' or shipment.destination.state == 'PR')
              xml.InvoiceLineTotal do
                xml.CurrencyCode shipment.value.currency
                xml.MonetaryValue( (shipment.value.cents.to_f / 100).round )
              end
            end

            shipment.packages.each do |package|
              add_package(xml, package, shipment.origin, shipment.international?, shipment.service, shipment.mail_innovations?, shipment.require_signature)
            end

            if shipment.international?
              package_description = shipment.packages.collect(&:customs_declarations).flatten.collect(&:description).first
              xml.Description package_description

              # TODO refactor into method
              package = shipment.packages.first
              if package.reference_1
                xml.ReferenceNumber do
                  xml.Code "R1"
                  xml.Value package.reference_1
                end
              end

              if package.reference_2
                xml.ReferenceNumber do
                  xml.Code "R2"
                  xml.Value package.reference_2
                end
              end

              if shipment.value
                # TODO combine me with the ShipmentServiceOptions above
                xml.ShipmentServiceOptions do
                  xml.InternationalForms do
                    xml.FormType '01' # Invoice

                    # TODO split this out into lots of Product entries
                    xml.Product do
                      xml.Description package_description

                      xml.Unit do
                        total_unit_count = shipment.packages.map(&:unit_count).map(&:to_i).sum

                        xml.Number total_unit_count
                        xml.Value((shipment.value.to_f / total_unit_count.to_f).round)

                        xml.UnitOfMeasurement do
                          xml.Code "EA"
                        end
                      end

                      xml.OriginCountryCode "US"
                    end

                    xml.InvoiceNumber package.reference_1
                    xml.InvoiceDate Time.now.strftime("%Y%m%d")
                    xml.PurchaseOrderNumber package.reference_1
                    xml.TermsOfShipment "CFR"
                    xml.ReasonForExport "SALE"
                    xml.DeclarationStatement "I hereby certify that the information on this invoice is true and correct and the contents and value of this shipment is as stated above."
                    xml.CurrencyCode "USD"
                  end
                end
              end
            end
          end
        end

        xml.target!
      end

      def build_shipment_accept_request(shipment, options={})
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.ShipmentAcceptRequest do
          xml.Request do
            xml.RequestAction 'ShipAccept'
            add_reference(xml, shipment)
          end
          xml.ShipmentDigest shipment[:digest]
        end
        xml.target!
      end

      def build_void_shipment_request(shipment)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.VoidShipmentRequest do
          xml.Request do
            xml.RequestAction '1'
          end
          add_reference(xml, shipment)
          xml.ShipmentIdentificationNumber shipment.tracking
        end
        xml.target!
      end

      def add_reference(xml, shipment)
        if shipment.number
          xml.TransactionReference do
            xml.CustomerContext shipment.number
          end
        end
      end

      def add_package(xml, package, origin, international, service, mail_innovations, require_signature)
        raise package.class.to_s unless package.kind_of?(ActiveMerchant::Shipping::Package)

        imperial = imperial? origin

        xml.Package do
          if mail_innovations
            xml.PackagingType { xml.Code '62' } # Irregulars
          else
            xml.PackagingType { xml.Code '02' } # Customer Supplied Package
          end

          unless package.description.blank?
            xml.Description package.description
          end

          axes = [:length, :width, :height]

          values = axes.map do |axis|
            if imperial
              package.inches(axis)
            else
              package.cm(axis)
            end
          end

          if values.all? {|v| v > 0 }
            xml.Dimensions do
              xml.UnitOfMeasurement do
                xml.Code(imperial ? 'IN' : 'CM')
              end

              axes.each_with_index do |axis, i|
                value = (values[i].to_f * 1000).round / 1000.0
                xml.tag!(axis.to_s.capitalize, [values[i], 0.1].max.to_s)
              end
            end
          end

          xml.PackageWeight do
            unit = weight_unit(origin, service)

            xml.UnitOfMeasurement do
              xml.Code(unit)
            end

            value = weight_sig_fig(package.send(unit.downcase.to_sym), service)

            xml.Weight [value, 0.1].max.to_s
          end

          xml.PackageServiceOptions do
            if require_signature
              xml.DeliveryConfirmation { xml.DCISType PACKAGE_DELIVERY_CONFIRMATION_CODES[:delivery_confirmation_signature_required] }
            end
            if package.insured_value
              if mail_innovations
                xml.DeliveryConfirmation { xml.DCISType PACKAGE_DELIVERY_CONFIRMATION_CODES[:usps_delivery_confirmation] }
              else
                xml.InsuredValue do
                  xml.CurrencyCode package.insured_value.currency
                  xml.MonetaryValue package.insured_value.cents.to_f / 100
                end
              end
            end
          end

          unless international || mail_innovations
            if package.reference_1
              xml.ReferenceNumber do
                xml.Code "R1"
                xml.Value package.reference_1
              end
            end

            if package.reference_2
              xml.ReferenceNumber do
                xml.Code "R2"
                xml.Value package.reference_2
              end
            end
          end
          # not implemented:  * Shipment/Package/LargePackageIndicator element
          #                   * Shipment/Package/ReferenceNumber element
          #                   * Shipment/Package/AdditionalHandling element
        end
      end

      def add_location(xml, name, object, options={}, international=false)
        xml.tag!(name) do
          shipment_name = object.name.to_s[0,35]
          shipment_company = object.company.to_s[0,35]
          if name == 'Shipper'
            xml.tag!('Name', object.company.to_s[0,35])
            xml.tag!('AttentionName', shipment_name) if international
          elsif name == 'ShipTo'
            if  options[:global_shipping]
              xml.tag!('CompanyName', shipment_company)
              xml.tag!('AttentionName', shipment_name)
            else
              xml.tag!('CompanyName', shipment_name)
              xml.tag!('AttentionName', shipment_name) if international
            end
          elsif name == 'SoldTo'
            xml.tag!('CompanyName', shipment_name)
            xml.tag!('AttentionName', shipment_name)
          elsif name == 'ShipFrom'
            if shipment_company.blank? && options[:return_detail].present?
              xml.tag!('CompanyName', shipment_name)
            else
              xml.tag!('CompanyName', shipment_company)
            end
          end

          unless object.phone.blank?
            xml.PhoneNumber object.phone.gsub(/[^\d]/, '')[0,15]
          end
          unless object.fax.blank?
            xml.FaxNumber object.phone.gsub(/[^\d]/, '')[0,14]
          end
          if name == 'Shipper'
            xml.ShipperNumber options[:account_id]
          elsif name == 'ShipTo' && options[:shipper_assigned_identification_number]
            xml.ShipperAssignedIdentificationNumber options[:shipper_assigned_identification_number]
          end
          xml.Address do
            values = [
              [object.address1,              :AddressLine1],
              [object.address2,              :AddressLine2],
              [object.address3,              :AddressLine3],
              [object.city,                  :City,              30],
              [object.province,              :StateProvinceCode, 5],
              [object.postal_code,           :PostalCode,        10],
              [object.country_code(:alpha2), :CountryCode]
            ]
            values.select {|v, n| v && v != '' }.each do |v, n, max_len|
              max_len ||= 35
              xml.tag!(n, v.to_s[0,max_len])
            end

            if name == "ShipTo"
              xml.ResidentialAddress "Y" unless object.commercial?
            end
          end
        end
      end

      def parse_money(element)
        value = element.elements['MonetaryValue'].text
        currency = element.elements['CurrencyCode'].text
        Money.new((BigDecimal(value) * 100).to_i, currency)
      end

      def parse_shipment_confirm(shipment, response)
        xml = REXML::Document.new(response)
        if response_success?(xml)
          confirm_response = xml.elements['/ShipmentConfirmResponse']

          value = confirm_response.elements['ShipmentCharges/TotalCharges']
          if( val = confirm_response.elements['NegotiatedRates/NetSummaryCharges/GrandTotal'] )
            value = val
          end
          shipment.price = value ? parse_money(value) : Money.new(0,'USD')
          shipment[:digest] = confirm_response.text('ShipmentDigest')
        else
          shipment.errors = response_message(xml)
        end
        shipment
      end

      def parse_shipment_accept(shipment, response)
        xml = REXML::Document.new(response)
        if response_success?(xml)
          shipment_results = xml.elements['/ShipmentAcceptResponse/ShipmentResults']

          value = shipment_results.elements['ShipmentCharges/TotalCharges']
          if( val = shipment_results.elements['NegotiatedRates/NetSummaryCharges/GrandTotal'] )
            value = val
          end
          shipment.price = value ? parse_money(value) : Money.new(0,'USD')
          if shipment.service == 'M4'
            shipment.tracking = shipment_results.elements['PackageResults'].text('USPSPICNumber')
          else
            shipment.tracking = shipment_results.elements['ShipmentIdentificationNumber'].text
          end
          shipment.labels = []
          shipment_results.elements.each('PackageResults') do |package_results|
            img = ''
            if package_results.elements['LabelImage']
              img = Base64.decode64(package_results.text('LabelImage/GraphicImage'))
            end
            shipment.labels << Label.new(:tracking => package_results.text('TrackingNumber'),
                                         :image    => img )
          end
          # ControlLogReceipts are for High-Value shipments (InsuredValue > $999)
          shipment_results.elements.each('ControlLogReceipt') do |control_log|
            shipment.labels << Label.new(
              :image => Base64.decode64(control_log.text('GraphicImage'))
            )
          end
        else
          shipment.errors = response_message(xml)
        end
        shipment
      end

      def parse_void_shipment(shipment, response)
        xml = REXML::Document.new(response)
        if response_success?(xml)
          shipment.tracking = nil
        else
          shipment.errors = response_message(xml)
        end
        shipment
      end

      def build_time_in_transit_request(shipment)
        imperial = imperial? shipment.origin

        packages = Array(packages)
        xml = Builder::XmlMarkup.new
        xml.instruct!

        xml.TimeInTransitRequest do
          xml.Request do
            xml.RequestAction 'TimeInTransit'
            xml.TransactionReference do
              xml.CustomerContext rand(100000).to_s
              xml.XpciVersion '1.0002'
            end
          end

          add_transit_location(xml, 'TransitFrom', shipment.origin)
          add_transit_location(xml, 'TransitTo', shipment.destination)

          xml.ShipmentWeight do
            unit = weight_unit(shipment.origin, shipment.service)

            xml.UnitOfMeasurement do
              xml.Code(unit)
            end

            value = weight_sig_fig(packages.sum(&unit.downcase.to_sym), shipment.service)

            xml.Weight [value, 0.1].max.to_s
          end

          xml.PickupDate Time.now.strftime('%Y%m%d')

          xml.InvoiceLineTotal do
            xml.CurrencyCode shipment.value.currency
            xml.MonetaryValue( (shipment.value.cents.to_f / 100).round )
          end

          #xml.TotalPackagesInShipment '1'
          xml.MaximumListSize '50'
        end

        xml.target!
      end

      def parse_time_in_transit_response(origin, shipment, response)
        xml = REXML::Document.new(response)
        if response_success?(xml)
          rate_estimates = xml.elements.collect('/TimeInTransitResponse/TransitResponse/ServiceSummary') do |service_offering|
            # These service codes are different from the Rating and Shipping APIs
            service_code = service_offering.get_text('Service/Code').to_s
            transit_time = service_offering.get_text('EstimatedArrival/BusinessTransitDays').to_s.to_i
            estimated_delivery_date = Date.parse(service_offering.get_text('EstimatedArrival/Date').to_s)
            RateEstimate.new(shipment.origin, shipment.destination, @@name,
                             time_in_transit_service_name_for(origin, service_code),
                             delivery_range: [transit_time.days.from_now, transit_time.days.from_now],
                             delivery_date: estimated_delivery_date)
          end
        else
          shipment.errors = response_message(xml)
        end
      end

      def add_transit_location(xml, name, location)
        xml.tag!(name) do
          xml.AddressArtifactFormat do
            xml.PoliticalDivision2 location.city
            xml.PoliticalDivision1 location.province
            xml.CountryCode        location.country_code(:alpha2)
            xml.PostcodePrimaryLow location.postal_code
            #xml.ResidentialAddressIndicator !location.commercial?
          end
        end
      end

      def build_address_validation_request(address, options={})
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.AddressValidationRequest do
          xml.Request do
            xml.RequestAction 'XAV'
          end
          xml.MaximumListSize options.fetch(:max_results, '3').to_s
          xml.AddressKeyFormat do
            xml.ConsigneeName address.name
            xml.AddressLine address.address1
            xml.AddressLine address.address2
            xml.PoliticalDivision2 address.city
            xml.PoliticalDivision1 address.state
            xml.PostcodePrimaryLow address.zip
            xml.CountryCode address.country_code || 'US'
          end
        end
        xml.target!
      end

      def parse_validate_address_response(response, options={})
        xml = REXML::Document.new(response)
        if response_success?(xml)
          response = xml.elements['AddressValidationResponse']

          fail ActiveMerchant::Shipping::ResponseError, 'UPS - No matching address found' if response.elements['NoCandidatesIndicator']

          addresses = []
          response_options = {}

          response_options[:valid_address_indicator] = response.elements['ValidAddressIndicator'] ? true : false

          response.get_elements('AddressKeyFormat').each do |address|
            fields = {}

            address.elements.each do |element|
              name = element.xpath.split('/').last.underscore.gsub(/\[\d\]/, '')
              fields.merge!({ name.to_sym => element.text }) do |key, old, new|
                old.is_a?(Array) ? old << new : [old, new]
              end
            end

            addresses << fields
          end

          response_options.merge!({ addresses: addresses })
          validation = AddressValidation::UpsResponse.new(response_options)
        else
          raise ActiveMerchant::Shipping::ResponseError, response_error_message(xml)
        end
        validation
      end

      def imperial?(origin)
        ['US','LR','MM'].include?(origin.country_code(:alpha2))
      end

      def weight_unit(origin, service = nil)
        if service == DEFAULT_SERVICES.key('UPS SurePost Less than 1lb') || service == DEFAULT_SERVICES.key("UPS Expedited Mail Innovations")
          'OZS'
        elsif imperial? origin
          'LBS'
        else
          'KGS'
        end
      end

      def weight_sig_fig(value, service)
        if service == DEFAULT_SERVICES.key('UPS SurePost Less than 1lb')
          (value.to_f * 10).round / 10.0 # 1 decimal
        else
          (value.to_f * 1000).round / 1000.0 # 3 decimals
        end
      end
    end
  end
end
