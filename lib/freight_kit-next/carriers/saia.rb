# frozen_string_literal: true

module FreightKit
  class SAIA < FreightKit::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    include FreightKit::Rateable
    include FreightKit::Trackable

    cattr_reader :name, :scac
    @@name = 'Saia'
    @@scac = 'SAIA'

    class << self
      def find_rates_implemented?
        true
      end

      def find_rates_with_declared_value?
        true
      end

      def maximum_height
        Measured::Length.new(105, :inches)
      end

      def maximum_weight
        Measured::Weight.new(10_000, :pounds)
      end

      def minimum_length_for_overlength_fees
        Measured::Length.new(8, :feet)
      end

      def overlength_fees_require_tariff?
        false
      end

      def required_credential_types
        %i[api]
      end

      def requirements
        %i[credentials]
      end
    end

    # Documents

    # Rates

    def validate_packages(packages, _tariff = nil)
      raise UnserviceableError, 'Must be fewer than 10 items altogether' if packages.sum(&:quantity) > 10

      super
    end

    protected

    def commit(action, request)
      client_args = {
        wsdl: request_url(action),
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
        soap_operation: @conf.dig(:api, :actions, action),
      ).call&.to_hash&.with_indifferent_access
    end

    def request_blueprint
      api_credentials = fetch_credential(:api)

      {
        request: {
          AccountNumber: api_credentials.account,
          Application: 'ThirdParty',
          Password: api_credentials.password,
          TestMode: 'N',
          UserID: api_credentials.username
        }
      }
    end

    def request_url(action)
      scheme = @conf.dig(:api, :use_ssl) ? 'https://' : 'http://'
      "#{scheme}#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
    end

    # Documents

    # Rates
    def build_rate_request(shipment:)
      accessorials = [{ AccessorialItem: { Code: 'SingleShipment' } }]
      if shipment.accessorials.present?
        serviceable_accessorials?(shipment.accessorials)
        shipment.accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorials << { AccessorialItem: { Code: @conf.dig(:accessorials, :mappable)[a] } }
          end
        end
      end

      longest_dimension = shipment.packages.map { |p| [p.width(:inches), p.length(:inches)].max }.max.ceil
      accessorials << { AccessorialItem: { Code: 'ExcessiveLength' } } if longest_dimension >= 96

      accessorials = accessorials.uniq

      details = []
      dimensions = []
      shipment.packages.each do |package|
        package.quantity.times do
          details << {
            DetailItem: {
              Weight: package.pounds(:each).ceil,
              Class: package.freight_class.to_s,
              Length: package.length(:in).ceil,
              Width: package.width(:in).ceil,
              Height: package.height(:in).ceil
            }
          }

          # Keeping this one at a time to match with "details"
          dimensions << {
            DimensionItem: {
              Units: 1,
              Length: package.length(:in).round(2),
              Width: package.width(:in).round(2),
              Height: package.height(:in).round(2),
              Type: 'IN' # inches
            }
          }
        end
      end

      request = {
        request: {
          Application: 'ThirdParty',
          BillingTerms: 'Prepaid',
          OriginCity: shipment.origin.city,
          OriginState: shipment.origin.province,
          OriginZipcode: shipment.origin.postal_code.to_s.upcase,
          DestinationCity: shipment.destination.city,
          DestinationState: shipment.destination.province,
          DestinationZipcode: shipment.destination.postal_code.to_s.upcase,
          WeightUnits: 'LBS',
          TotalCube: shipment.packages.sum { |p| p.cubic_ft(:each) }.round(2),
          TotalCubeUnits: 'CUFT', # cubic ft
          ExcessiveLengthTotalInches: longest_dimension.to_s,
          Details: details,
          Dimensions: dimensions,
          Accessorials: accessorials
        }
      }

      declared_value = if shipment.declared_value_cents.blank?
                         nil
                       else
                         (shipment.declared_value_cents.to_f / 100).ceil
                       end

      if declared_value.present?
        request = request.deep_merge(
          {
            request: {
              DeclaredValue: declared_value,
              FullValueCoverage: declared_value
            }
          },
        )
      end

      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:)
      rate_response = RateResponse.new(request: last_request, response:)

      if response.blank?
        rate_response.error = ResponseError.new('Unknown response')
        return rate_response
      end

      error = response.dig(:create_response, :create_result, :code)

      if error.present?
        message = response.dig(:create_response, :create_result, :message)

        case error
        when 'DNF'
          rate_response.error = UnserviceableError.new("#{error}: #{message}")
          return rate_response
        when 'S10'
          rate_response.error = UnserviceableError.new("#{error}: #{message}")
          return rate_response
        end

        if message.downcase.include?('must not exceed 10 lines')
          rate_response.error = UnserviceableError.new("#{error}: #{message}")
          return rate_response
        end

        rate_response.error = ResponseError.new("#{error}: #{message}")
        return rate_response
      end

      result = response.dig(:create_response, :create_result)

      if result.blank?
        rate_response.error = ResponseError.new('Unknown result')
        return rate_response
      end

      if result[:total_invoice].blank?
        rate_response.error = ResponseError.new('Cost is blank')
        return rate_response
      end

      transit_days = result[:standard_service_days].to_i
      estimate_reference = result[:quote_number]

      rate_accessorial_items = result.dig(:rate_accessorials, :rate_accessorial_item)
      rate_accessorial_items = [rate_accessorial_items] if rate_accessorial_items.is_a?(Hash)

      prices = []

      rate_accessorial_items.each do |rate_accessorial_item|
        prices << Price.new(
          blame: :api,
          cents: (rate_accessorial_item[:amount].to_f * 100).to_i,
          description: rate_accessorial_item[:description]&.titleize&.squish,
        )
      end

      standard_ltl_cents = (result[:total_invoice].to_f * 100).to_i - prices.sum(&:cents)

      rates = []

      rates << Rate.new(
        carrier: self,
        carrier_name: self.class.name,
        currency: 'USD',
        estimate_reference:,
        scac: self.class.scac.upcase,
        service_name: :standard,
        shipment:,
        prices: [
                  Price.new(
                    blame: :api,
                    cents: standard_ltl_cents,
                    description: 'Freight',
                  ),
                ] + prices,
        transit_days:,
        with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees),
      )

      [
        { guaranteed_ltl: result[:guarantee_amount] },
        { guaranteed_ltl_am: result[:guarantee_amount12pm] },
        { guaranteed_ltl_pm: result[:guarantee_amount2pm] },
      ].each do |service|
        next if service.values[0] == '0' || service.values[0].blank?

        cents = (service.values[0].to_f * 100).to_i

        rates << Rate.new(
          carrier_name: self.class.name,
          carrier: self,
          currency: 'USD',
          estimate_reference:,
          scac: self.class.scac.upcase,
          service_name: service.keys[0],
          shipment:,
          prices: [
                    Price.new(
                      blame: :api,
                      cents: standard_ltl_cents + cents,
                      description: 'Freight',
                    ),
                  ] + prices,
          with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees),
        )
      end

      rate_response.rates = rates
      rate_response
    end

    # Tracking

    def build_tracking_request(tracking_number)
      request = {
        request: {
          ProNumber: tracking_number
        }
      }
      save_request(request)
      request
    end

    def parse_api_date_time(date_time, location)
      return if date_time.blank?

      local_date_time = ::Time.strptime(date_time, '%Y-%m-%d %H:%M:%S').to_fs(:db)
      ::FreightKit::DateTime.new(local_date_time:, location:)
    end

    def parse_api_location(api_event)
      Location.new(
        city: api_event[:city]&.titleize,
        province: api_event[:state]&.upcase,
        country: ActiveUtils::Country.find('USA'),
      )
    end

    def parse_tracking_response(response)
      tracking_response = TrackingResponse.new(carrier: self, request: last_request, response:)

      error = if response
                response.dig(:get_by_pro_number_response, :get_by_pro_number_result, :code)
              else
                'API Error: Unknown response'
              end

      if error.present?
        tracking_response.error = ResponseError.new(error)
        return tracking_response
      end

      search_result = response.dig(:get_by_pro_number_response, :get_by_pro_number_result)

      if search_result.blank?
        tracking_response.error = ShipmentNotFoundError.new
        return tracking_response
      end

      address1 = [
                   search_result.dig(:shipper, :address1),
                   search_result.dig(:shipper, :address2),
                 ]
                 .select(&:present?)
                 .map { |line| line.squish.strip.titleize }
                 .join(', ')

      shipper_location = Location.new(
        address1:,
        city: search_result.dig(:shipper, :city)&.squish&.strip&.titleize,
        province: search_result.dig(:shipper, :state)&.strip&.upcase,
        postal_code: search_result.dig(:shipper, :zipcode)&.strip,
        country: ActiveUtils::Country.find('USA'),
      )

      address1 = [
                   search_result.dig(:consignee, :address1),
                   search_result.dig(:consignee, :address2),
                 ]
                 .select(&:present?)
                 .map { |line| line.squish.strip.titleize }
                 .join(', ')

      receiver_location = Location.new(
        address1:,
        city: search_result.dig(:consignee, :city)&.squish&.strip&.titleize,
        province: search_result.dig(:consignee, :state)&.strip&.upcase,
        postal_code: search_result.dig(:consignee, :zipcode)&.strip,
        country: ActiveUtils::Country.find('USA'),
      )

      api_date_time = search_result[:delivery_date_time_arrive]
      actual_delivery_date = parse_api_date_time(api_date_time, receiver_location)

      api_date_time = search_result[:pickup_date_time]
      pickup_date = parse_api_date_time(api_date_time, shipper_location)

      api_date_time = search_result[:delivery_appointment_date_time]
      scheduled_delivery_date = parse_api_date_time(api_date_time, receiver_location)

      tracking_number = search_result[:pro_number]

      shipment_events = []

      api_events = search_result.dig(:history, :history_item)

      if api_events.blank?
        shipment_events << ShipmentEvent.new(
          date_time: pickup_date,
          location: shipper_location,
          type_code: :picked_up,
        )
      else
        api_events = [api_events] if api_events.is_a?(Hash)

        api_events.each do |api_event|
          event_key = nil
          comment = api_event[:activity]

          @conf.dig(:events, :types).each do |key, val|
            if comment.downcase.include?(val)
              event_key = key
              break
            end
          end
          next if event_key.blank?

          api_date_time = api_event[:activity_date_time]

          location = parse_api_location(api_event)
          date_time = parse_api_date_time(api_date_time, location)

          shipment_events << ShipmentEvent.new(date_time:, location:, type_code: event_key)
        end
      end

      status = shipment_events.last&.type_code

      tracking_response.assign_attributes(
        actual_delivery_date:,
        destination: receiver_location,
        origin: shipper_location,
        scheduled_delivery_date:,
        ship_time: pickup_date,
        shipment_events:,
        status:,
        tracking_number:,
      )

      tracking_response
    end
  end
end
