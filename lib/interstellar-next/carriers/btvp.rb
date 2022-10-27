# frozen_string_literal: true

module Interstellar
  class BTVP < TheGreatInformationFactory
    REACTIVE_FREIGHT_CARRIER = true

    include Interstellar::Rateable
    include Interstellar::Trackable

    cattr_reader :name, :scac
    @@name = 'Best Overnite Express'
    @@scac = 'BTVP'

    def maximum_height
      Measured::Length.new(105, :inches)
    end

    def maximum_weight
      Measured::Weight.new(10_000, :pounds)
    end

    def minimum_length_for_overlength_fees
      Measured::Length.new(8, :feet)
    end

    def required_credential_types
      %i[api selenoid website]
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
      parse_pickup_response(
        delivery_from:,
        delivery_to:,
        dispatcher:,
        pickup_from:,
        pickup_to:,
        scac:,
        service:,
        shipment:
      )
    end

    def create_pickup_implemented?
      true
    end

    # Documents

    def download_document(_type, _tracking_number, url)
      document_response = DocumentResponse.new(request: url)

      begin
        response = HTTParty.get(url)
      rescue StandardError => e
        document_response.error = e
        return document_response
      end

      if response.code != 200 || response.headers['content-type'].include?('html')
        document_response.error = DocumentNotFoundError.new
        return document_response
      end

      document_response.assign_attributes(content_type: response.headers['content-type'], data: response.body)
      document_response
    end

    def parse_document_response(type, tracking_number)
      document_response = DocumentResponse.new

      selenoid_credentials = fetch_credential(:selenoid)
      website_credentials = fetch_credential(:website)

      browser = Watir::Browser.new(*selenoid_credentials.watir_args)
      browser.goto(build_url(:pod))

      browser.text_field(name: 'userid').set(website_credentials.username)
      browser.text_field(name: 'password').set(website_credentials.password)
      browser.button(name: 'btnLogin').click

      begin
        browser.html
      rescue Selenium::WebDriver::Error::JavascriptError
        document_response.error = Interstellar::ResponseError

        return document_response
      end

      if browser.html.include?('Password not correct')
        browser.close

        document_response.error = Interstellar::InvalidCredentialsError.new
        return document_response
      end

      if browser.html.include?('You are not enrolled in any application environments on this server')
        browser.close

        document_response.error = Interstellar::InvalidCredentialsError.new(
          'You are not enrolled in any application environments on this server'
        )
        return document_response
      end

      if browser.html.include?('You already have the maximum permitted application sessions open')
        browser.close

        document_response.error = Interstellar::InvalidCredentialsError.new(
          'You already have the maximum permitted application sessions open'
        )
        return document_response
      end

      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[2]/img').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[3]/ul[2]/li').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[3]/ul[2]/li[6]/span[2]').wait_until(&:present?).click
      browser.select_list(name: 'TATIWT').select('S')

      browser.textarea(name: 'TATFB').set(tracking_number)
      browser.button(xpath: '/html/body/div[1]/div[3]/div[3]/div/div[1]/div/button[2]').click

      sleep(5)

      unless browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div[1]/div[4]/div[3]/div/table/tbody/tr[2]/td[2]').exists?
        browser.element(xpath: '/html/body/div[1]/div[1]/div[2]/div[4]').wait_until(&:present?).click
        browser.element(xpath: '/html/body/div[12]/div[11]/div/button[1]').wait_until(&:present?).click
        browser.close

        document_response.error = Interstellar::ShipmentNotFoundError
        return document_response
      end

      browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div[1]/div[4]/div[3]/div/table/tbody/tr[2]/td[2]').double_click

      sleep(5)

      unless browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div/div/form/div[4]/div[2]/div/div/table').exists?
        browser.element(xpath: '/html/body/div[1]/div[1]/div[2]/div[4]').wait_until(&:present?).click
        browser.element(xpath: '/html/body/div[12]/div[11]/div/button[1]').wait_until(&:present?).click
        browser.close

        document_response.error = Interstellar::DocumentNotFoundError
        return document_response
      end

      html = browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div/div/form/div[4]/div[2]/div/div/table').inner_html
      html = Nokogiri::HTML.parse(html)

      link_id = nil
      html.css('tr').each do |tr|
        next unless tr.text.downcase.include?(@conf.dig(:documents, :types, type).downcase)

        link_id = tr.css('td')[1].css('a').to_html.split('id=')[1].split('onfocus')[0].gsub('"', '').strip
      end

      if link_id.blank?
        document_response.error = Interstellar::DocumentNotFoundError
        return document_response
      end

      browser.element(css: "##{link_id}").click
      url = browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/embed').attribute_value('src')

      doc = download_document(type, tracking_number, url)

      browser.element(xpath: '/html/body/div[1]/div[1]/div[2]/div[4]').click
      browser.element(xpath: '/html/body/div[12]/div[11]/div/button[1]').wait_until(&:present?).click
      browser.close

      doc
    end

    # Pickups

    def parse_pickup_response(
      delivery_from:,
      delivery_to:,
      dispatcher:,
      pickup_from:,
      pickup_to:,
      scac:,
      service:,
      shipment:
    )
      selenoid_credentials = fetch_credential(:selenoid)
      website_credentials = fetch_credential(:website)

      browser = Watir::Browser.new(*selenoid_credentials.watir_args)
      browser.goto(build_url(:pickup))

      browser.text_field(name: 'userid').set(website_credentials.username)
      browser.text_field(name: 'password').set(website_credentials.password)
      browser.button(name: 'btnLogin').click

      if browser.html.include?('Password not correct')
        browser.close

        document_response.error = Interstellar::InvalidCredentialsError.new
        return document_response
      end

      if browser.html.include?('You are not enrolled in any application environments on this server')
        browser.close
        raise Interstellar::InvalidCredentialsError,
              'You are not enrolled in any application environments on this server'
      end

      if browser.html.include?('You already have the maximum permitted application sessions open')
        browser.close
        raise Interstellar::ResponseError, 'You already have the maximum permitted application sessions open'
      end

      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[2]/img').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[3]/ul[2]/li').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[1]/div[2]/div[2]/div[1]/div[3]/ul[2]/li[2]/span[2]').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div[1]/div[6]/div/table/tbody/tr/td[1]/table/tbody/tr/td[2]/div/span/img').wait_until(&:present?).click

      shipper_name = shipment.origin.contact.company_name.upcase.squish.strip
      new_customer = true

      browser.select_list(id: 'DPSC').wait_until(&:present?).click

      if browser.select_list(id: 'DPSC').options.to_a.map(&:text).include?(shipper_name)
        new_customer = false
        browser.option(text: shipper_name).click
      else
        browser.option(text: '<new>').click

        browser.text_field(name: 'SHPNAM').set(shipper_name.upcase)
        browser.text_field(name: 'SHPAD1').set(shipment.origin.address1.upcase)
        browser.text_field(name: 'SHPCTY').set(shipment.origin.city.upcase)
        browser.text_field(name: 'SHPSTA').set(shipment.origin.province.upcase[..1])
        browser.text_field(name: 'SHPZIP').set(shipment.origin.postal_code.gsub(/\s+/, '').upcase)
      end

      browser.text_field(name: 'DPADAT').set(pickup_from.to_date.strftime('%m/%d/%Y'))
      browser.text_field(name: 'DPATIM').set(pickup_from.strftime('%H:%M'))
      browser.text_field(name: 'DPCTIM').set(pickup_to.strftime('%H:%M'))

      total_weight = shipment.packages.map { |p| p.pounds(:total) }.sum.ceil

      browser.text_field(name: 'DSTWT_1').set(total_weight)
      browser.text_field(name: 'DSDZIP_1').set(shipment.destination.postal_code.gsub(/\s+/, '').upcase)
      browser.text_field(name: 'DSTPC_1').set(shipment.packages.map(&:quantity).sum)
      browser.text_field(name: 'DSPLT_1').set(shipment.packages.map(&:quantity).sum)

      browser.checkbox(name: 'DSHAZ_1').check if shipment.hazmat?

      browser.checkbox(name: 'DSLIFT_1').check if shipment.accessorials.include?(:liftgate_pickup)

      browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div/div[2]/div/div[1]/div/button[2]/span').click
      # Click Button Create

      has_form_error = browser.text_field(class: /rns-ui-error/).locate.located?

      if has_form_error
        # Logout
        browser.element(xpath: '/html/body/div[1]/div[1]/div[2]/div[4]').wait_until(&:present?).click
        browser.element(xpath: '/html/body/div[10]/div[11]/div/button[1]').wait_until(&:present?).click

        browser.close
        raise Interstellar::ResponseError, 'Invalid Pickup Form Data'
      end

      if new_customer
        browser.radio(id: 'CCS', value: 'NEW').wait_until(&:present?).select
        browser.element(xpath: '/html/body/div[3]/div[2]/div[2]/div/div[1]/div/button[1]').click
      end

      browser.text_field(name: 'DPADAT').wait_until(&:present?).set(pickup_from.to_date.strftime('%m/%d/%Y'))
      browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/form[1]/div/div[2]/div/div/table/tbody/tr/td[2]/a/img').click

      html = browser.element(xpath: '/html/body/div[1]/div[3]/div[2]/div/div[1]/div[3]/div[3]/div/table').wait_until(&:present?).html
      html = Nokogiri::HTML.parse(html)

      pickup_number = nil

      html.css('tr').each do |tr|
        next unless tr.text.include?(shipper_name) && tr.text.include?(total_weight.try(:to_s))

        # Convert total_weight to string. .include?(Integer) will raise no implicit conversion of Integer into String (TypeError)
        # Used 'try(:to_s)' so that it would still return nil if nil, and not return '' blank string

        pickup_number = tr.css('td')[1].text
      end

      # Logout
      browser.element(xpath: '/html/body/div[1]/div[1]/div[2]/div[4]').wait_until(&:present?).click
      browser.element(xpath: '/html/body/div[10]/div[11]/div/button[1]').wait_until(&:present?).click

      browser.close

      pickup_response = PickupResponse.new(request: nil, response: html)

      if pickup_number.blank?
        pickup_response.error = Interstellar::ResponseError.new('Unknown response')
        return pickup_response
      end

      pickup_response.pickup_number = pickup_number
      pickup_response
    end
  end
end
