# frozen_string_literal: true

module Interstellar
  class CLNI < Interstellar::Carrier
    REACTIVE_FREIGHT_CARRIER = true

    cattr_reader :name, :scac
    @@name = 'Clear Lane Freight Systems'
    @@scac = 'CLNI'

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
      %i[api website]
    end

    # Documents

    def pod(tracking_number)
      parse_document_response(:pod, tracking_number)
    end

    def pod_implemented?
      true
    end

    def scanned_bol(tracking_number)
      parse_document_response(:bol, tracking_number)
    end

    def scanned_bol_implemented?
      true
    end

    # Rates

    def find_rates(shipment:)
      begin
        validate_packages(shipment.packages)
      rescue UnserviceableError => e
        return RateResponse.new(error: e)
      end

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit_soap(:rates, request))
    end

    def find_rates_implemented?
      true
    end

    def find_rates_with_declared_value?
      false # API allows it but doesn't quote correctly per support
    end

    def validate_packages(packages)
      raise UnserviceableError, 'Must be fewer than 10 items altogether' if packages.sum(&:quantity) > 10

      super
    end

    # Tracking

    protected

    def commit_soap(action, request)
      Savon.client(
        wsdl: build_url(:api, action),
        convert_request_keys_to: :none,
        env_namespace: :soap,
        element_form_default: :qualified
      ).call(
        @conf.dig(:api, :actions, action),
        message: request_blueprint.deep_merge(request)
      )&.body&.to_hash&.with_indifferent_access
    end

    def request_blueprint
      api_credentials = credentials.find { |c| c.type == :api }

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

    def build_url(api_or_website, action)
      case api_or_website
      when :api
        scheme = @conf.dig(:api, :use_ssl) ? 'https://' : 'http://'
        "#{scheme}#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :endpoints, action)}"
      when :website
        @conf.dig(:website, action)
      end
    end

    # Documents

    def parse_document_response(action, _tracking_number)
      document_response = DocumentResponse.new

      selenoid_credentials = credentials.find { |c| c.type == :selenoid }
      website_credentials = credentials.find { |c| c.type == :website }

      browser = Watir::Browser.new(*selenoid_credentials.watir_args)
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
      browser
        .element(xpath: '/html/body/form/div[3]/div[4]/div[3]/div[2]/div/div/div[3]/div')
        .wait_until(&:present?)
        .click

      browser.button(name: 'btnSubmit').click

      browser.text_field(id: 'yadcf-filter--grid-2').set('1054360')
      browser.send_keys(:enter)

      if browser.element(id: 'tdPODName0').wait_until(&:present?).text == 'NO POD' && action == :pod
        browser.window.close
        browser.original_window.use
        browser.goto('https://ssworldtrak.com/WebtrakWTNew/logoff.aspx')
        browser.close

        document_response.error = DocumentNotFoundError.new
        return document_response
      end

      browser
        .element(xpath: '/html/body/form/div[3]/div[4]/div[8]/div/table/tbody/tr/td[12]/a')
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

      download_url = "#{selenoid_credentials.download_url}/#{browser.driver.session_id}"
      response = HTTParty.get("#{download_url}/?json")

      filename = CGI.escape(JSON.parse(response.body)&.last)
      url = "#{download_url}/#{filename}"

      document_response.request = URI.parse(url)

      begin
        response = HTTParty.get(url)
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

    # Rates

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
      unless shipment.accessorials.blank?
        serviceable_accessorials?(shipment.accessorials)
        shipment.accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorial_input << { AccessorialInput: { AccessorialCode: @conf.dig(:accessorials, :mappable)[a] } }
          end
        end
      end

      accessorial_input.uniq!

      commodity_input = build_commodity_input(shipment.packages)

      pickup_from = ::DateTime.current.beginning_of_day + 14.hours
      pickup_from += 1.day if ::DateTime.current > pickup_from
      pickup_to = pickup_from + 3.hours

      api_credentials = credentials.find { |c| c.type == :api }

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
            Palletized: shipment.packages.map(&:packaging).map(&:pallet?).any?(false) ? 'N' : 'Y',
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

    def parse_rate_response(shipment:, response:)
      rate_response = RateResponse.new(request: last_request, response:)

      if response.blank?
        rate_response.error = ResponseError.new('Blank response')
        return rate_response
      end

      error = response.dig(:get_rating_response, :get_rating_result, :rating_output, :message)

      unless error.blank?
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
        prices << Price.new(
          blame: :api,
          cents: 0,
          description: accessorial_output_description(accessorial_output)
        )
      end

      transit_days = response[:transit_days].to_i

      rate = Rate.new(
        carrier: self,
        carrier_name: self.class.name,
        currency: 'USD',
        estimate_reference: nil,
        scac: self.class.scac.upcase,
        service_name: :standard,
        shipment:,
        prices:,
        transit_days:,
        with_excessive_length_fees: @conf.dig(:attributes, :rates, :with_excessive_length_fees)
      )

      rate_response.rates = [rate]
      rate_response
    end

    def accessorial_output_description(accessorial_output)
      return '' if accessorial_output[:accessorial_desc].blank?

      description = accessorial_output[:accessorial_desc]
      description = description.capitalize
      description.gsub('Smc', 'SMC')
    end

    def parse_amount(amount)
      %w[$ ,].each do |char|
        amount = amount.sub(char, '')
      end

      return 0 if amount.blank?

      amount = (amount.to_f * 100).to_i
    end

    # Tracking
  end
end
