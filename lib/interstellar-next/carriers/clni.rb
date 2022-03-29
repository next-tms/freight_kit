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

    # Documents

    def find_bol(tracking_number, options = {})
      options = @options.merge(options)
      parse_document_response(:bol, tracking_number, options)
    end

    def find_bol_implemented?
      true
    end

    def find_pod(tracking_number, options = {})
      options = @options.merge(options)
      parse_document_response(:pod, tracking_number, options)
    end

    def find_pod_implemented?
      true
    end

    # Rates
    def find_rates(shipment:)
      validate_packages(shipment.packages)
      raise UnserviceableError, 'Must be fewer than 10 items altogether' if shipment.packages.sum(&:quantity) > 10

      request = build_rate_request(shipment:)
      parse_rate_response(shipment:, response: commit_soap(:rates, request))
    end

    def find_rates_implemented?
      true
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
      {
        'request': {
          'Application': 'ThirdParty',
          'AccountNumber': @options[:account],
          'UserID': @options[:username],
          'Password': @options[:password],
          'TestMode': @options[:debug].blank? ? 'N' : 'Y'
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

    def parse_document_response(action, tracking_number, options = {})
      browser = Watir::Browser.new(*options[:watir_args])
      browser.goto('https://ssworldtrak.com/WebtrakWTNew/')

      browser.text_field(name: 'txtUserId').set('JFJTRANS')
      browser.text_field(name: 'txtPass').set('Clear193')
      browser.button(name: 'btnSubmit').click

      if browser.html.include?('Either UserID or Password are incorrect, please try again.')
        browser.close
        raise Interstellar::InvalidCredentialsError
      end

      # Bypass the hover menu
      browser.goto('https://ssworldtrak.com/WebtrakWTNew/Main/Reports/POD.aspx')

      from = 90.days.ago.strftime('%m%d%Y')

      browser.text_field(name: 'txtFromDate').wait_until(&:present?).focus

      # Hack to get around JavaScript messing up our input
      sleep(1)

      from.split('').each do |char|
        browser.text_field(name: 'txtFromDate').append(char)
      end

      browser.text_field(name: 'txtToDate').click
      browser.element(xpath: '/html/body/form/div[3]/div[4]/div[3]/div[2]/div/div/div[3]/div').wait_until(&:present?).click

      browser.button(name: 'btnSubmit').click

      browser.text_field(id: 'yadcf-filter--grid-2').set('1054360')
      browser.send_keys(:enter)

      if browser.element(id: 'tdPODName0').wait_until(&:present?).text == 'NO POD' && action == :pod
        browser.window.close
        browser.original_window.use
        browser.goto('https://ssworldtrak.com/WebtrakWTNew/logoff.aspx')
        browser.close

        raise Interstellar::DocumentNotFoundError, "API Error: #{@@name}: Document not found"
      end

      browser.element(xpath: '/html/body/form/div[3]/div[4]/div[8]/div/table/tbody/tr/td[12]/a').wait_until(&:present?).click

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

        raise Interstellar::DocumentNotFoundError, "API Error: #{@@name}: Document not found"
      end

      browser.element(css: "##{link_id}").click

      sleep(10) # so Chrome can finish downloading

      pdf_path = nil

      if !options.dig(:selenoid_options, :download_url)
        pdf_path = Dir.glob("#{tmpdir}/*.pdf").max_by { |f| File.mtime(f) }
      else
        download_url = "#{options.dig(:selenoid_options, :download_url)}/#{browser.driver.session_id}"
        response = HTTParty.get("#{download_url}/?json")

        filename = CGI.escape(JSON.parse(response.body)&.last)
        pdf_url = "#{download_url}/#{filename}"
        pdf_path = File.join(tmpdir, "#{tracking_number}_#{DateTime.current}.pdf")

        File.open(pdf_path, 'wb') do |file|
          HTTParty.get(pdf_url, stream_body: true) do |fragment|
            file.write(fragment)
          end
        end
      end

      browser.window.close
      browser.original_window.use
      browser.goto('https://ssworldtrak.com/WebtrakWTNew/logoff.aspx')
      browser.close

      return Interstellar::ResponseError if !pdf_path || !File.exist?(pdf_path)

      path = if options[:path].blank?
               File.join(tmpdir, "#{self.class.name} #{tracking_number} #{action.to_s.upcase}.pdf")
             else
               options[:path]
             end
      file = File.new(path, 'w')

      File.exist?(path) ? path : false
    end

    # Rates
    def build_rate_request(shipment:)
      accessorial_input = []
      unless shipment.accessorials.blank?
        serviceable_accessorials?(shipment.accessorials)
        shipment.accessorials.each do |a|
          unless @conf.dig(:accessorials, :unserviceable).include?(a)
            accessorial_input << { 'AccessorialInput': { 'AccessorialCode': @conf.dig(:accessorials, :mappable)[a] } }
          end
        end
      end

      accessorial_input.uniq!

      commodity_input = []
      dimensions = []
      shipment.packages.each do |package|
        commodity_input << {
          'CommodityInput': {
            'CommodityClass': package.freight_class,
            'CommodityHazmat': package.hazmat? ? 'Y' : 'N',
            'CommodityHeight': package.height(:in).ceil,
            'CommodityLength': package.length(:in).ceil,
            'CommodityPieces': package.quantity,
            'CommodityPieceType': package.packaging.pallet? ? 'pallet' : 'box',
            'CommodityWeight': package.pounds(:total).ceil,
            'CommodityWeightPerPiece': package.pounds(:each).ceil,
            'CommodityWidth': package.width(:in).ceil
          }
        }
      end

      pickup_from = DateTime.current.beginning_of_day + 14.hours
      pickup_from += 1.day if DateTime.current > pickup_from
      pickup_to = pickup_from + 3.hours

      request = {
        'RatingParam': {
          'AccessorialInput': accessorial_input,
          'CommodityInput': commodity_input,
          'RatingInput': {
            'DeclaredValue': 0,
            'DestinationCity': shipment.destination.city,
            'DestinationCountry': shipment.destination.country.code(:alpha2).value,
            'DestinationState': shipment.destination.state,
            'DestinationZip': shipment.destination.zip,
            'LiabilityType': '',
            'OriginCity': shipment.origin.city,
            'OriginCountry': shipment.origin.country.code(:alpha2).value,
            'OriginState': shipment.origin.state,
            'OriginZip': shipment.origin.zip,
            'Palletized': shipment.packages.map(&:packaging).map(&:pallet?).any?(false) ? 'N' : 'Y',
            'PickupDate': pickup_from.to_date.strftime('%Y-%m-%d'),
            'PickupLocationCloseTime': pickup_to.strftime('%H:%M:00'),
            'PickupTime': pickup_from.strftime('%H:%M:00'),
            'RequestID': rand(0..999_999).to_s,
            'ServiceLevelID': '',
            'ShipmentTerms': '',
            'Stackable': false,
            'WebTrakUserID': @options[:username]
          }
        }
      }

      save_request(request)
      request
    end

    def parse_rate_response(shipment:, response:)
      raise Interstellar::ResponseError, 'API Error: Blank response' if response.blank?

      error = response.dig(:get_rating_response, :get_rating_result, :rating_output, :message)

      unless error.blank?
        if error.include?('do not service this lane')
          raise Interstellar::UnserviceableError,
                'Incorrect ZIP code or no service available at origin and/or destination'
        end

        pretty_error = error.strip.gsub('can not', 'cannot')
        raise Interstellar::ResponseError, pretty_error
      end

      result = response.dig(:get_rating_response, :get_rating_result, :rating_output)
      raise Interstellar::ResponseError, 'API Error: Blank response' if result.blank?

      cents = parse_amount(result[:standard_total_rate])
      raise Interstellar::ResponseError, 'Cost is blank' if cents.blank?

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

      RateResponse.new(
        rates: [
          Rate.new(
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
        ],
        response:,
        request: last_request
      )
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
