require 'spec_helper'

describe FreightKit::Platforms::RoadVision do
  let(:carrier) { Class.new(described_class).new(FreightKit::Credential.new(type: :api, username: 'user', password: 'pass')) }

  let(:shipment) do
    contact = FreightKit::Contact.new(company_name: 'Acme', name: 'Pat', phone: '+12065550100')
    country = ActiveUtils::Country.find('US')
    destination = FreightKit::Location.new(address1: '2 Oak St', city: 'Austin', country:, postal_code: '78701-1234', province: 'TX')
    origin = FreightKit::Location.new(address1: '1 Main St', city: 'Seattle', contact:, country:, postal_code: '98101', province: 'WA')
    package = FreightKit::Package.new(7680, { length: 40, width: 40, height: 40 }, :pallet, units: :imperial, quantity: 2)

    FreightKit::Shipment.new(accessorials: [], destination:, origin:, packages: [package], po_number: 'PO1')
  end

  # Responses arrive as parsed JSON, with PascalCase string keys
  def json_response(body)
    parsed_response = body.deep_transform_keys { |key| key.to_s.camelize }

    instance_double(FreightKit::HTTPClient::Response, body: parsed_response.to_json, code: 200, parsed_response:)
  end

  def url(endpoint) = "https://relmapi.roadvision.com/api/#{endpoint}"

  it { expect(described_class::API[:domain]).to(eq('relmapi.roadvision.com')) }
  it { expect(described_class.required_credential_types).to(eq(%i[api])) }
  it { expect(described_class.requirements).to(eq(%i[credentials tariff])) }
  it { expect(described_class.services).to(eq(%i[standard])) }
  it { expect(described_class.superclass).to(eq(FreightKit::Platform)) }

  describe '#create_pickup' do
    subject(:pickup_response) { carrier.create_pickup(**options, shipment:) }

    let(:body) { JSON.parse(carrier.last_request[:body]).deep_transform_keys { |key| key.underscore.to_sym } }
    let(:freight) { { freight_class: '125', height: 40, length: 40, pallet_count: 2, piece_count: 2, weight: 480, width: 40 } }
    let(:options) { { delivery_from: nil, delivery_to: nil, dispatcher: nil, pickup_from:, pickup_to:, scac: nil, service: :standard } }
    let(:pickup_from) { ActiveSupport::TimeZone['America/Los_Angeles'].local(2026, 11, 3, 8) }
    let(:pickup_to) { pickup_from + 8.hours }
    let(:response) { json_response(error_info: '', pickup_number: 42) }

    before do
      allow(FreightKit::HTTPClient).to(receive(:request).and_return(response))
      pickup_response
    end

    it { expect(FreightKit::HTTPClient).to(have_received(:request).with(:post, url('SubmitPickupRequest'), any_args)) }
    it { expect(body).to(include(closing_time: '16:00', pickup_date: '11/03/2026', ready_by_time: '08:00')) }
    it { expect(body).to(include(consignee_zip: '78701', shipper_name: 'Acme', shipper_phone: '+12065550100')) }
    it { expect(body[:freight_list]).to(eq([freight])) }
    it { expect(body).to(include(logon: 'user', pass: 'pass', ponum: 'PO1')) }
    it { expect(body).not_to(have_key(:quote_num)) }
    it { expect(carrier.last_request[:body]).to(include('"CODAmountInCents":0', '"PONUM":"PO1"', '"PPDorCOL":"PPD"')) }
    it { expect(pickup_response).to(have_attributes(error: nil, pickup_number: '42')) }

    context 'with a quote' do
      let(:shipment) { super().tap { |shipment| shipment.estimate_reference = '14' } }

      it { expect(body).to(include(quote_num: 14)) }
    end

    context 'with an error' do
      let(:response) { json_response(error_info: 'Invalid pickup date', pickup_number: 0) }

      it { expect(pickup_response.error).to(be_a(FreightKit::ResponseError).and(have_attributes(message: 'Invalid pickup date'))) }
    end
  end

  describe '#find_rates' do
    subject(:rate_response) { carrier.find_rates(shipment:) }

    let(:prices) { { 'Freight' => 20_000, 'Fuel surcharge' => 4_000, 'Other' => 1_000 } }
    let(:quote) do
      quote_details = [{ amount: 200.0, description: 'Freight ' }, { amount: 40.0, description: 'Fuel surcharge' }]

      json_response(error_info: '', quote_details:, quote_number: 14, total: 250.0)
    end
    let(:rate) { rate_response.rates.first }
    let(:transit_time) { json_response(error_info: '', transit_days: '3') }

    before do
      allow(FreightKit::HTTPClient).to(receive(:request).with(:post, any_args).and_return(quote))
      allow(FreightKit::HTTPClient).to(receive(:request).with(:get, any_args).and_return(transit_time))
    end

    it { expect(rate).to(have_attributes(estimate_reference: '14', total_cents: 25_000, transit_days: 3)) }
    it { expect(rate.prices.to_h { |price| [price.description, price.cents] }).to(eq(prices)) }

    it do
      rate_response
      query = hash_including('DestinationZip' => '78701', 'OriginZip' => '98101')
      expect(FreightKit::HTTPClient).to(have_received(:request).with(:get, url('TransitTime'), hash_including(query:)))
    end

    context 'with an error' do
      let(:quote) { json_response(error_info: 'Invalid logon', total: 0) }

      it { expect(rate_response.error).to(have_attributes(message: 'Invalid logon')) }
    end

    context 'when the transit time lookup fails' do
      before { allow(FreightKit::HTTPClient).to(receive(:request).with(:get, any_args).and_raise(FreightKit::HTTPError.new(body: '', code: 500))) }

      it { expect(rate).to(have_attributes(total_cents: 25_000, transit_days: nil)) }
    end

    context 'with accessorials it does not map' do
      before { shipment.accessorials = %i[liftgate_delivery] }

      it { expect { rate_response }.to(raise_error(FreightKit::UnserviceableAccessorialsError)) }
    end
  end

  describe '#find_tracking_info' do
    subject(:tracking_response) { carrier.find_tracking_info('1234') }

    let(:data) do
      {
        error_message: '',
        general_info: { 'BOLnumber' => '68118', pro_number: '1234', shipment_date: '11/02/2026', who_signed: 'PAT ' },
        ship_from: { city: 'SEATTLE', name: 'ACME', state: 'wa', zip: '98101' },
        ship_to: { city: 'AUSTIN', state: 'TX', zip: '78701' },
        status_list: [
          { status_code: 'AF', status_date: '11/02/2026', status_time: '9:30' },
          { status_code: 'ZZ', status_date: '11/03/2026', status_time: '10:00' },
          { status_code: 'D1', status_date: '11/04/2026', status_definition: 'Completed Unloading', status_time: '14:05' }
        ]
      }
    end
    let(:delivered_at) { ActiveSupport::TimeZone['America/Chicago'].local(2026, 11, 4, 14, 5) }

    before { allow(FreightKit::HTTPClient).to(receive(:request).and_return(json_response(data))) }

    it { expect(tracking_response.actual_delivery_date.date_time_with_zone).to(eq(delivered_at)) }
    it { expect(tracking_response).to(have_attributes(delivery_signature: 'PAT', status: :delivered)) }
    it { expect(tracking_response.ship_time).to(be_a(FreightKit::DateTime).and(have_attributes(local_date: Date.new(2026, 11, 2)))) }
    it { expect(tracking_response).to(have_attributes(status_code: 'D1', status_description: 'Completed Unloading')) }
    it { expect(tracking_response.origin).to(have_attributes(city: 'Seattle', province: 'WA')) }
    it { expect(tracking_response.origin.contact.company_name).to(eq('ACME')) }
    it { expect(tracking_response.shipment_events.map(&:type_code)).to(eq(%i[picked_up delivered])) }
    it { expect(tracking_response.response[:general_info]).to(include(bol_number: '68118')) }
    it { expect(tracking_response.tracking_number).to(eq('1234')) }

    it do
      tracking_response
      expect(carrier.last_request[:query]).to(eq('Pass' => 'pass', 'SearchFor' => '1234', 'SearchType' => 1, 'User' => 'user'))
    end

    context 'with a status at 00:00, which means it has no time' do
      let(:data) { super().tap { |data| data[:status_list].last[:status_time] = '00:00' } }

      it { expect(tracking_response.actual_delivery_date).to(have_attributes(date_time_with_zone: nil, local_date: Date.new(2026, 11, 4))) }
    end

    context 'with an error' do
      let(:data) { { error_message: 'Pro not found' } }

      it { expect(tracking_response.error).to(have_attributes(message: 'Pro not found')) }
    end
  end

  describe '#invoice' do
    subject(:invoice_response) { carrier.invoice('1234') }

    let(:invoice) do
      detail = {
        balance_due: '0.00',
        consignee_city: 'AUSTIN',
        consignee_name: 'WIDGETS',
        consignee_state: 'TX',
        consignee_zip: '78701',
        delivery_date: '11/04/2026',
        original_charges: '$1,250.00',
        pickup_date: '11/02/2026',
        pro_number: '1234',
        shipper_city: 'SEATTLE',
        shipper_state: 'WA',
        shipper_zip: '98101'
      }

      {
        error_info: '',
        invoice_amount: '1,250.00',
        invoice_balance: '125.50',
        invoice_date: '11/05/2026',
        invoice_details: [detail],
        invoice_number: '502'
      }
    end
    let(:list) { { error_info: '', invoice_pick_list: [{ invoice_number: '77' }, { invoice_number: '502' }] } }
    let(:pdf) { instance_double(FreightKit::HTTPClient::Response, body: '%PDF-1.4', code: 200) }

    before do
      allow(FreightKit::HTTPClient).to(receive(:request).with(:get, url('FetchInvoiceListByPro'), any_args).and_return(json_response(list)))
      allow(FreightKit::HTTPClient).to(receive(:request).with(:get, url('FetchInvoiceData'), any_args).and_return(json_response(invoice)))
      allow(FreightKit::HTTPClient).to(receive(:request).with(:get, url('FetchInvPDF'), any_args).and_return(pdf))
    end

    it { expect(invoice_response).to(have_attributes(balance_cents: 12_550, number: '502', total_cents: 125_000)) }
    it { expect(invoice_response).to(have_attributes(content_type: 'application/pdf', data: '%PDF-1.4', error: nil)) }
    it { expect(invoice_response.issued_on).to(eq(Date.new(2026, 11, 5))) }
    it { expect(invoice_response.lines.first).to(have_attributes(balance_cents: 0, total_cents: 125_000, tracking_number: '1234')) }
    it { expect(invoice_response.lines.first.delivered_on).to(eq(Date.new(2026, 11, 4))) }
    it { expect(invoice_response.lines.first.destination.contact.company_name).to(eq('WIDGETS')) }
    it { expect(invoice_response.lines.first.origin).to(have_attributes(city: 'Seattle', postal_code: '98101', province: 'WA')) }

    it do
      invoice_response
      query = hash_including('DocNumber' => '502')
      expect(FreightKit::HTTPClient).to(have_received(:request).with(:get, url('FetchInvPDF'), hash_including(query:)))
    end

    it do
      invoice_response
      expect(FreightKit::HTTPClient).to(have_received(:request).with(:get, url('FetchInvoiceData'), hash_including(read_timeout: 120)))
    end

    context 'without an invoice' do
      let(:list) { { error_info: '', invoice_pick_list: [] } }

      it { expect(invoice_response.error).to(be_a(FreightKit::DocumentNotFoundError)) }
    end

    context 'when the shipment is not invoiced yet' do
      let(:list) { { error_info: 'No corresponding invoices on file for this pro', invoice_pick_list: [] } }

      it { expect(invoice_response.error).to(be_a(FreightKit::DocumentNotFoundError)) }
    end

    context 'without a PDF' do
      let(:pdf) { instance_double(FreightKit::HTTPClient::Response, body: '{"Message":"No document"}', code: 200) }

      it { expect(invoice_response).to(have_attributes(data: nil, error: be_a(FreightKit::DocumentNotFoundError), total_cents: 125_000)) }
    end
  end

  describe '#pod' do
    subject(:document_response) { carrier.pod('1234') }

    let(:response) { instance_double(FreightKit::HTTPClient::Response, body: '%PDF-1.4', code: 200) }

    before { allow(FreightKit::HTTPClient).to(receive(:request).and_return(response)) }

    it { expect(document_response).to(have_attributes(content_type: 'application/pdf', data: '%PDF-1.4', error: nil)) }

    it do
      document_response
      query = { 'Pass' => 'pass', 'SearchFor' => '1234', 'SearchType' => 1, 'User' => 'user' }
      expect(carrier.last_request).to(include(query:, url: url('FetchPOD')))
    end

    context 'without a document' do
      let(:response) { instance_double(FreightKit::HTTPClient::Response, body: '', code: 200) }

      it { expect(document_response.error).to(be_a(FreightKit::DocumentNotFoundError)) }
    end
  end
end
