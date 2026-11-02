require 'spec_helper'

describe FreightKit::Platforms::NextTMS do
  let(:carrier) { orm.platform }
  let(:carrier_class) { Class.new(described_class) { const_set(:API, FreightKit::Platforms::NextTMS::API.deep_merge(domain: 'tms.example.com')) } }
  let(:orm) { carrier_class::ORM }

  let(:shipment) do
    {
      broker_carrier: { account: 'ACCT', carrier: { id: '3', scac: 'JFJT' }, id: '12' },
      delivered_at: '2026-10-30T15:00:00Z',
      delivery_eta_on: '2026-10-30',
      id: '1',
      load_id: 1234,
      pro: 'PRO1',
      shipper_address: { city: 'Seattle', country: { alpha2_code: 'US' }, id: '7', region: { abbreviation: 'WA' }, zip_code: '98101' },
      status: 'delivered',
      total_charges_cents: 50_000
    }
  end

  let(:data) { { shipments: { items: [shipment], page: 1, page_size: 1, pages: 3, total_items: 3, version: '3-20261030150000' } } }
  let(:download) { instance_double(FreightKit::HTTPClient::Response, body: '%PDF', code: 200, content_type: 'application/pdf') }

  let(:freight) do
    contact = FreightKit::Contact.new(company_name: 'Acme', email: 'dock@example.com', name: 'Pat', phone: '+12065550100')
    country = ActiveUtils::Country.find('US')
    destination = FreightKit::Location.new(city: 'Austin', country:, postal_code: '78701', province: 'TX')
    origin = FreightKit::Location.new(address1: '1 Main St', city: 'Seattle', contact:, country:, postal_code: '98101', province: 'WA')
    package = FreightKit::Package.new(7680, { length: 48, width: 40, height: 40 }, :pallet, units: :imperial, quantity: 2)

    FreightKit::Shipment.new(accessorials: %i[liftgate_delivery], destination:, origin:, packages: [package])
  end

  let(:quote) do
    {
      quote_create: {
        rates: [rate, rate.merge(charge_cents: 9_000, id: 'r2', scac: 'ODFL'), rate.merge(charge_cents: nil, id: 'r3')],
        shipment: { id: '5', load_id: 4321 }
      }
    }
  end
  let(:rate) do
    {
      carrier_name: 'JFJ', charge_cents: 12_000, charge_currency: 'USD', expires_at: '2026-11-09T00:00:00Z', id: 'r1', scac: 'JFJT',
      transit_days: 2
    }
  end
  let(:response) { graphql_response(data:) }

  # Responses arrive as parsed JSON, with camelCase string keys
  def graphql_response(**body)
    parsed_response = body.deep_transform_keys { |key| key.to_s.camelize(:lower) }

    instance_double(FreightKit::HTTPClient::Response, code: 200, parsed_response:)
  end

  def variables = carrier.last_request[:variables]

  before do
    FreightKit.cache = ActiveSupport::Cache::MemoryStore.new
    orm.credentials = FreightKit::Credential.new(type: :api_key, api_key: 'tms_key')
    allow(FreightKit::HTTPClient).to(receive(:request).and_return(response))
  end

  after { FreightKit.cache = nil }

  it { expect(described_class::API).not_to(have_key(:domain)) }
  it { expect(described_class.overlength_fees_require_tariff?).to(be(false)) }
  it { expect(described_class.pickup_number_is_tracking_number?).to(be(true)) }
  it { expect(described_class.required_credential_types).to(eq(%i[api_key])) }
  it { expect(described_class.serviceable_accessorials?(%i[liftgate_delivery])).to(be(true)) }
  it { expect(described_class.services).to(eq(%i[standard])) }
  it { expect(described_class.superclass).to(eq(FreightKit::Platform)) }

  describe '#bol' do
    subject(:document_response) { carrier.bol('1234') }

    let(:data) { { shipments: { items: [{ documents:, id: '1', load_id: 1234 }] } } }

    let(:documents) do
      [
        { content_type: 'application/pdf', filename: 'pod.pdf', kind: 'POD', url: 'https://storage.example.com/pod.pdf' },
        { content_type: 'application/pdf', filename: 'bol.pdf', kind: 'BOL', url: '/rails/active_storage/blobs/redirect/bol.pdf' }
      ]
    end

    before do
      allow(FreightKit::HTTPClient).to(receive(:request).with(:get, any_args).and_return(download))
      document_response
    end

    it { expect(FreightKit::HTTPClient).to(have_received(:request).with(:get, 'https://tms.example.com/rails/active_storage/blobs/redirect/bol.pdf')) }
    it { expect(document_response).to(have_attributes(content_type: 'application/pdf', data: '%PDF', error: nil)) }
    it { expect(carrier.last_request[:body]).to(include('"loadIdEq":1234')) }

    context 'with the POD' do
      subject(:document_response) { carrier.pod('1234') }

      it { expect(FreightKit::HTTPClient).to(have_received(:request).with(:get, 'https://storage.example.com/pod.pdf')) }
    end

    context 'with the scanned BOL, which customers cannot see' do
      subject(:document_response) { carrier.scanned_bol('1234') }

      it { expect(document_response.error).to(be_a(FreightKit::DocumentNotFoundError)) }
    end

    context 'with the invoice of a missing shipment' do
      subject(:document_response) { carrier.invoice('1234') }

      let(:data) { { shipments: { items: [] } } }

      it { expect(document_response.error).to(be_a(FreightKit::ShipmentNotFoundError)) }
    end
  end

  describe '#create_pickup' do
    subject(:pickup_response) { carrier.create_pickup(**options, scac:) }

    let(:booked) { { shipment_create: { shipment: { documents:, id: '5', load_id: 4321, pro: nil, status: 'booked' } } } }
    let(:booking) { [graphql_response(data: quote), graphql_response(data: booked)] }
    let(:documents) { [{ kind: 'BOL', url: '/bol.pdf' }, { content_type: 'application/pdf', kind: 'LABEL', url: '/label.pdf' }] }
    let(:hours) { { pickup_hours_end_at: '2026-11-03T16:00:00-08:00', pickup_on: Date.new(2026, 11, 3) } }
    let(:logger) { instance_double(Logger, warn: nil) }
    let(:options) { { delivery_from: nil, delivery_to: nil, dispatcher: nil, pickup_from:, pickup_to:, service: :standard, shipment: } }
    let(:shipment) { freight }
    let(:pickup_from) { ActiveSupport::TimeZone['America/Los_Angeles'].local(2026, 11, 3, 8) }
    let(:pickup_on) { include('"pickupOn":"2026-11-03"') }
    let(:pickup_to) { pickup_from + 8.hours }
    let(:responses) { [*booking, download] }
    let(:scac) { 'JFJT' }

    def documents_response(*documents) = graphql_response(data: { shipments: { items: [{ documents:, id: '5', load_id: 4321 }] } })

    before do
      allow(carrier).to(receive(:sleep))
      allow(FreightKit::HTTPClient).to(receive_messages(logger:))
      allow(FreightKit::HTTPClient).to(receive(:request).and_return(*responses))
      pickup_response
    end

    it { expect(FreightKit::HTTPClient).to(have_received(:request).with(:get, 'https://tms.example.com/label.pdf')) }
    it { expect(FreightKit::HTTPClient).to(have_received(:request).with(:post, anything, body: pickup_on, headers: anything, read_timeout: 300).twice) }
    it { expect(carrier).not_to(have_received(:sleep)) }
    it { expect(pickup_response.labels.map(&:data)).to(eq(['%PDF'])) }
    it { expect(pickup_response.pickup_number).to(eq('4321')) }
    it { expect(variables[:input]).to(include(**hours, rate_id: 'r1')) }
    it { expect(variables.dig(:input, :shipper)).to(include(contact_email: 'dock@example.com', contact_name: 'Pat', name: 'Acme')) }

    context 'when the TMS generates the label after booking' do
      let(:documents) { [] }
      let(:label) { { content_type: 'application/pdf', kind: 'LABEL', url: '/label.pdf' } }
      let(:responses) { [*booking, documents_response, documents_response(label), download] }

      it { expect(carrier).to(have_received(:sleep).twice) }
      it { expect(pickup_response.labels.map(&:data)).to(eq(['%PDF'])) }
    end

    context 'when the TMS never generates the label' do
      let(:documents) { [] }
      let(:responses) { [*booking, documents_response] }

      it { expect(carrier).to(have_received(:sleep).exactly(described_class::LABEL_WAITS.size).times) }
      it { expect(pickup_response).to(have_attributes(error: nil, labels: [], pickup_number: '4321')) }
    end

    context 'when the label download fails' do
      let(:responses) { [*booking, instance_double(FreightKit::HTTPClient::Response, body: '', code: 500)] }

      it { expect(logger).to(have_received(:warn).with(/4321 booked without labels: FreightKit::HTTPError/)) }
      it { expect(pickup_response).to(have_attributes(error: nil, labels: [], pickup_number: '4321')) }
    end

    context 'without a SCAC' do
      let(:scac) { nil }

      it { expect(variables.dig(:input, :rate_id)).to(eq('r2')) }
    end

    context 'when no rate is from the SCAC' do
      let(:scac) { 'SAIA' }

      it { expect(FreightKit::HTTPClient).to(have_received(:request).once) }
      it { expect(pickup_response.error).to(be_a(FreightKit::UnserviceableError)) }
    end
  end

  describe '#find_rates' do
    subject(:rate_response) { carrier.find_rates(shipment: freight) }

    let(:data) { quote }
    let(:package) { { declared_freight_class: nil, height: 40, length: 48, packaging: 'pallet', quantity: 2, weight: 480, width: 40 } }

    before { rate_response }

    it { expect(carrier.last_request[:body]).to(include('"regionIso31662":"US_WA"')) }
    it { expect(rate_response.error).to(be_nil) }

    it do
      expect(rate_response.rates.first).to(have_attributes(carrier_name: 'JFJ', currency: 'USD', estimate_reference: '4321',
                                                           total_cents: 12_000))
    end

    it { expect(rate_response.rates.first.expires_at).to(eq(Time.utc(2026, 11, 9))) }

    it { expect(rate_response.rates.map(&:scac)).to(eq(['JFJT', 'ODFL'])) }
    it { expect(variables[:input]).to(include(accessorial_codes: ['liftgate_delivery'], declared_freight_classes: false)) }
    it { expect(variables.dig(:input, :packages)).to(contain_exactly(include(package.compact))) }

    it do
      expect(variables.dig(:input,
                           :shipper_address)).to(eq(city: 'Seattle', region_iso31662: 'US_WA', street: '1 Main St', zip_code: '98101'))
    end

    context 'when no carrier quotes' do
      let(:data) { { quote_create: { rates: [], shipment: { id: '5', load_id: 4321 } } } }

      it { expect(rate_response.error).to(be_a(FreightKit::UnserviceableError)) }
    end

    context 'when the customer cannot get an accessorial' do
      let(:extensions) { { accessorialCodes: ['liftgate_delivery'], code: 'UNSERVICEABLE_ACCESSORIALS' } }
      let(:response) { graphql_response(data: nil, errors: [{ extensions:, message: 'Accessorials not offered: liftgate_delivery' }]) }

      it { expect(rate_response.error).to(have_attributes(accessorials: %i[liftgate_delivery], class: FreightKit::UnserviceableAccessorialsError)) }
    end
  end

  describe '#find_tracking_info' do
    subject(:tracking_response) { carrier.find_tracking_info('1234') }

    let(:shipment) do
      shipper_address = super()[:shipper_address].merge(time_zone_name: 'America/Los_Angeles')

      super().merge(picked_up_at: '2026-10-28T18:00:00Z', shipper_address:)
    end

    before { tracking_response }

    it { expect(tracking_response.actual_delivery_date.date_time_with_zone).to(eq(Time.utc(2026, 10, 30, 15))) }
    it { expect(tracking_response.error).to(be_nil) }
    it { expect(tracking_response.estimated_delivery_date.local_date).to(eq(Date.new(2026, 10, 30))) }
    it { expect(tracking_response.origin).to(have_attributes(city: 'Seattle', province: 'WA')) }
    it { expect(tracking_response.shipment_events.first.date_time.date_time_with_zone.time_zone.name).to(eq('America/Los_Angeles')) }
    it { expect(tracking_response.shipment_events.first.location).to(have_attributes(city: 'Seattle')) }
    it { expect(tracking_response.shipment_events.map(&:type_code)).to(eq(%i[picked_up delivered])) }
    it { expect(tracking_response.status).to(eq(:delivered)) }
    it { expect(tracking_response.status_code).to(eq('delivered')) }
    it { expect(tracking_response.tracking_number).to(eq('1234')) }
    it { expect(variables[:filter]).to(eq(load_id_eq: 1234)) }
    it { expect(variables[:page_size]).to(eq(1)) }

    context 'with scan events' do
      let(:events) do
        [
          {
            city: 'Seattle', country_alpha2: 'US', id: '1', occurred_at: '2026-10-28T18:00:00Z', region_iso31662: 'US-WA',
            type_code: 'picked_up', zip_code: '98101'
          },
          {
            city: 'Portland', country_alpha2: 'US', id: '2', occurred_at: '2026-10-29T06:00:00Z', region_iso31662: 'US-OR',
            type_code: 'arrived_at_terminal', zip_code: '97201'
          },
          { id: '3', occurred_at: nil, type_code: 'lost' }
        ]
      end
      let(:scan) { tracking_response.shipment_events.last }
      let(:shipment) { super().merge(events:) }

      it { expect(scan.date_time.date_time_with_zone.time_zone.name).to(eq('America/Los_Angeles')) }
      it { expect(scan.location).to(have_attributes(city: 'Portland', postal_code: '97201', province: 'OR')) }
      it { expect(tracking_response.shipment_events.map(&:type_code)).to(eq(%i[picked_up arrived_at_terminal])) }
      it { expect(tracking_response.status).to(eq(:arrived_at_terminal)) }
    end

    context 'when delivered at the time of pickup' do
      let(:shipment) { super().merge(delivered_at: '2026-10-28T18:00:00Z') }

      it { expect(tracking_response.shipment_events.map(&:type_code)).to(eq(%i[picked_up delivered])) }
    end

    context 'when lost on the day of pickup' do
      let(:shipment) { super().merge(delivered_at: nil, lost_on: '2026-10-28') }

      it { expect(tracking_response.status).to(eq(:lost)) }

      context 'when the pickup is after midnight UTC' do
        let(:shipment) { super().merge(picked_up_at: '2026-10-29T03:00:00Z') }

        it { expect(tracking_response.status).to(eq(:lost)) }
      end
    end

    context 'when delivered on an earlier local day than the pickup, in a time zone further west' do
      let(:receiver_address) { { city: 'Honolulu', country: { alpha2_code: 'US' }, id: '8', time_zone_name: 'Pacific/Honolulu' } }
      let(:shipment) { super().merge(delivered_at: '2026-10-30T08:00:00Z', picked_up_at: '2026-10-30T07:30:00Z', receiver_address:) }

      it { expect(tracking_response.status).to(eq(:delivered)) }
    end

    context 'with a date-only delivery appointment' do
      let(:shipment) { super().merge(delivery_appointment_on: '2026-10-29') }

      it { expect(tracking_response.scheduled_delivery_date.local_date).to(eq(Date.new(2026, 10, 29))) }
    end

    context 'when no load ID matches' do
      let(:responses) { [graphql_response(data: { shipments: { items: [] } }), response] }

      before do
        allow(FreightKit::HTTPClient).to(receive(:request).and_return(*responses))
        carrier.find_tracking_info('1234')
      end

      it { expect(variables[:filter]).to(eq(or: [{ pro_eq: '1234' }, { tracking_carrier_pro_eq: '1234' }])) }
      it { expect(variables[:page_size]).to(eq(2)) }
    end
  end

  describe '#find_tracking_info by PRO' do
    it { expect(carrier.find_tracking_info('PRO1')).to(have_attributes(error: nil, status: :delivered)) }

    context 'with a number too long for a load ID' do
      before { carrier.find_tracking_info('12345678901') }

      it { expect(variables[:filter]).to(eq(or: [{ pro_eq: '12345678901' }, { tracking_carrier_pro_eq: '12345678901' }])) }
    end
  end

  describe '#find_tracking_info when a PRO matches a load ID' do
    let(:data) { { shipments: { items: [shipment.merge(id: '2', load_id: 9, pro: '1234'), shipment] } } }

    it { expect(carrier.find_tracking_info('1234').response).to(include(load_id: 1234)) }
  end

  describe '#find_tracking_info when several shipments have the PRO' do
    let(:data) { { shipments: { items: [shipment, shipment.merge(id: '2', load_id: 9)] } } }

    it { expect { carrier.find_tracking_info('PRO1') }.to(raise_error(FreightKit::ResponseError, /PRO of several shipments/)) }
    it { expect(carrier.valid_tracking_number?('PRO1')).to(be(true)) }
  end

  describe '#find_tracking_info when missing' do
    let(:data) { { shipments: { items: [], page: 1, page_size: 1, pages: 0, total_items: 0, version: '0' } } }

    it { expect(carrier.find_tracking_info('1234').error).to(be_a(FreightKit::ShipmentNotFoundError)) }
    it { expect(carrier.valid_tracking_number?('1234')).to(be(false)) }
  end

  describe '#find_tracking_number_from_pickup_number' do
    it { expect(carrier.find_tracking_number_from_pickup_number('1234', Date.current)).to(eq('1234')) }
  end

  describe '#valid_tracking_number?' do
    it { expect(carrier.valid_tracking_number?(1234)).to(be(true)) }
  end

  describe 'GraphQLClient::Query' do
    queries = %i[
      BrokerCarrier BrokerCarriers BrokerCustomer BrokerCustomers Carrier Carriers Customer Customers
      Invoice Invoices Shipment ShipmentDocuments Shipments
    ]

    queries.each do |query|
      it { expect(FreightKit::Platforms::NextTMS::GraphQLClient::Query.const_get(query)::DETAILS).to(be_a(GraphQL::Client::OperationDefinition)) }
    end
  end

  describe 'GraphQLClient::Mutation' do
    %i[QuoteCreate ShipmentCreate].each do |mutation|
      it { expect(FreightKit::Platforms::NextTMS::GraphQLClient::Mutation.const_get(mutation)::DETAILS).to(be_a(GraphQL::Client::OperationDefinition)) }
    end
  end

  describe 'Invoice' do
    subject(:invoice) { orm::Invoice.first }

    let(:data) do
      {
        invoices: {
          items: [{ due_on: '2026-11-30', id: '9', number: '1234', shipment: { id: '1', load_id: 1234 }, total_cents: 50_000 }],
          page: 1, page_size: 1, total_items: 1, version: '1'
        }
      }
    end

    it { expect(invoice).to(have_attributes(due_on: Date.new(2026, 11, 30), number: '1234', total_cents: 50_000)) }
    it { expect(invoice.shipment.load_id).to(eq(1234)) }
  end

  describe 'ORM' do
    it { expect(orm.platform).to(be_a(carrier_class)) }
    it { expect(orm::Shipment.graphql_name).to(eq('Shipment')) }
    it { expect(orm::Shipment.superclass).to(eq(FreightKit::Platforms::NextTMS::ORM::Shipment)) }
    it { expect { FreightKit::Platforms::NextTMS::ORM::Shipment.first }.to(raise_error(ArgumentError, /not bound to a tenant/)) }
  end

  describe 'ORM without credentials' do
    before { orm.credentials = nil }

    it { expect { orm::Shipment.first }.to(raise_error(ArgumentError, /credentials is not set/)) }
  end

  describe '#query' do
    before { carrier.query(:shipments, page_size: 1) }

    it { expect(JSON.parse(carrier.last_request[:body], symbolize_names: true)[:variables]).to(eq(pageSize: 1)) }
    it { expect(carrier.last_request[:headers]).to(include('X-API-Key': 'tms_key')) }
    it { expect(carrier.last_request[:url]).to(eq('https://tms.example.com/graphql')) }
    it { expect(variables).to(eq(page_size: 1)) }
  end

  describe '#query with errors' do
    let(:response) { graphql_response(errors: [{ extensions: { code: 'PAGE_OVERFLOW' }, message: 'Page 9 is out of range' }]) }

    it { expect { carrier.query(:shipments) }.to(raise_error(FreightKit::ResponseError, 'PAGE_OVERFLOW: Page 9 is out of range')) }
  end

  describe '#query when the API key is rejected' do
    let(:response) { instance_double(FreightKit::HTTPClient::Response, code: 401, parsed_response: nil, to_s: 'API key expired') }

    it { expect { carrier.query(:shipments) }.to(raise_error(FreightKit::InvalidCredentialsError)) }
  end

  describe '#query when rate limited' do
    let(:response) { instance_double(FreightKit::HTTPClient::Response, body: '', code: 429, headers: { 'retry-after' => '42' }) }

    it { expect { carrier.query(:shipments) }.to(raise_error(FreightKit::RateLimitError) { |error| expect(error.retry_after).to(eq(42)) }) }
  end

  describe '#query with cache' do
    before { 2.times { carrier.query(:shipments, cache: true) } }

    it { expect(FreightKit::HTTPClient).to(have_received(:request).once) }
  end

  describe 'Shipment.where' do
    let(:filter) do
      { load_id_eq: 1234, or: [{ shipper_name_cont: 'Acme' }, { pro_eq: 'PRO1' }], pro_null: false, status_eq: 'delivered' }
    end

    before do
      alternatives = [{ shipper_name_cont: 'Acme' }, { pro: 'PRO1' }]
      orm::Shipment.where(load_id: 1234, status: :delivered).not(pro: nil).where(or: alternatives).first
    end

    it { expect(variables[:filter]).to(eq(filter)) }
    it { expect(variables[:page_size]).to(eq(1)) }
  end

  describe 'Shipment.not' do
    let(:filter) { { broker_carrier_id_not_eq: 12, delivered_at_lt: '2026-10-01T00:00:00Z', pro_not_eq: 'PRO1', status_eq: 'delivered' } }

    let(:conditions) { { delivered_at: Time.utc(2026, 10, 1).., pro_eq: 'PRO1', status_not_eq: 'delivered' } }

    before { orm::Shipment.not(broker_carrier: orm::BrokerCarrier.new('12'), **conditions).first }

    it { expect(variables[:filter]).to(eq(filter)) }
  end

  describe 'Shipment.not with several predicates' do
    it { expect { orm::Shipment.not(delivered_at: Time.utc(2026, 10, 1)..Time.utc(2026, 11, 1)) }.to(raise_error(ArgumentError)) }
    it { expect { orm::Shipment.not(or: [{ pro: 'A' }, { pro: 'B' }]) }.to(raise_error(ArgumentError)) }
  end

  describe 'Shipment.where with ranges, arrays and records' do
    let(:broker_carrier) { orm::BrokerCarrier.new('12') }
    let(:filter) { { broker_carrier_id_eq: 12, delivered_at_gteq: '2026-10-01T00:00:00Z', status_in: ['delivered', 'canceled'] } }

    before { orm::Shipment.where(broker_carrier:, delivered_at: Time.utc(2026, 10, 1).., status: %i[delivered canceled]).to_a }

    it { expect(variables[:filter]).to(eq(filter)) }
  end

  describe 'Shipment.order.offset.limit' do
    before { orm::Shipment.order(delivered_at: :desc).offset(40).limit(20).to_a }

    it { expect(variables[:page]).to(eq(3)) }
    it { expect(variables[:page_size]).to(eq(20)) }
    it { expect(variables[:sort]).to(eq(['delivered_at:desc'])) }
  end

  describe 'Shipment.limit.offset' do
    before { orm::Shipment.limit(20).offset(40).to_a }

    it { expect(variables[:page]).to(eq(3)) }
  end

  describe 'Shipment.offset that does not start a page' do
    it { expect { orm::Shipment.offset(1).limit(20) }.to(raise_error(ArgumentError, /multiple of the limit/)) }
    it { expect { orm::Shipment.limit(20).offset(1) }.to(raise_error(ArgumentError, /multiple of the limit/)) }
    it { expect { orm::Shipment.offset(40).to_a }.to(raise_error(ArgumentError, /needs a limit/)) }
  end

  describe 'Shipment.limit' do
    subject(:shipments) { orm::Shipment.limit(1) }

    it { expect(shipments.count).to(eq(3)) }
    it { expect(shipments.total_items).to(eq(3)) }
    it { expect(shipments.total_pages).to(eq(3)) }
    it { expect(shipments.tap(&:to_a).version).to(eq('3-20261030150000')) }
  end

  describe 'Shipment.none' do
    subject(:shipments) { orm::Shipment.none }

    it { expect(shipments).to(be_empty) }
    it { expect { shipments.find('1') }.to(raise_error(described_class::ORM::RecordNotFoundError)) }
    it { expect(shipments.to_a).to(eq([])) }
  end

  describe 'Shipment.where.find' do
    subject(:shipments) { orm::Shipment.where(status: :delivered).limit(1) }

    it { expect(shipments.find('01')).to(have_attributes(id: '1')) }
    it { expect(shipments.find('1')).to(have_attributes(id: '1', loaded?: true)) }
    it { expect { shipments.find('9') }.to(raise_error(described_class::ORM::RecordNotFoundError)) }
  end

  describe 'Shipment.where.find without a limit' do
    let(:data) { { shipments: { items: [shipment], page: 1, page_size: 1, pages: 1, total_items: 1 } } }

    before { orm::Shipment.where(status: :delivered).find('1') }

    it { expect(FreightKit::HTTPClient).to(have_received(:request).once) }
    it { expect(variables[:filter]).to(eq(id_eq: 1, status_eq: 'delivered')) }
  end

  describe 'Shipment.find_by! with an ID and other conditions' do
    before { orm::Shipment.find_by!(id: '1', status: :delivered) }

    it { expect(variables[:filter]).to(eq(id_eq: 1, status_eq: 'delivered')) }
  end

  describe 'Shipment.where with a conflicting ID' do
    it { expect { orm::Shipment.where(id: 1).find(2) }.to(raise_error(described_class::ORM::RecordNotFoundError)) }
    it { expect { orm::Shipment.where(id: 1).find_by!(id: 2, status: :delivered) }.to(raise_error(described_class::ORM::RecordNotFoundError)) }
    it { expect(orm::Shipment.where(status: :delivered).where(status: 'delivered').filter).to(eq(status_eq: 'delivered')) }
  end

  describe 'Shipment.where with empty arrays' do
    it { expect(orm::Shipment.not(broker_carrier: []).where(status: :delivered).filter).to(eq(status_eq: :delivered)) }
    it { expect(orm::Shipment.where(broker_carrier: [])).to(be_empty) }
    it { expect(orm::Shipment.where(or: [{ status: [] }])).to(be_empty) }
    it { expect(orm::Shipment.where(or: [{ status: [] }, { pro: 'A' }]).filter).to(eq(or: [{ pro_eq: 'A' }])) }
    it { expect(orm::Shipment.where(status: [])).to(be_empty) }
    it { expect(orm::Shipment.where(status: :delivered, status_not_in: []).filter).to(eq(status_eq: :delivered)) }
  end

  describe 'Shipment.where twice with the same predicate' do
    let(:dates) { orm::Shipment.where(pickup_on: Date.new(2026, 10, 1)..).where(pickup_on_gteq: '2026-10-02') }
    let(:instants) { orm::Shipment.where(delivered_at: later).where(delivered_at_eq: '2026-10-01T17:00:00-07:00') }
    let(:later) { Time.utc(2026, 10, 2) }
    let(:offsets) { orm::Shipment.where(delivered_at_gteq: '2026-10-01T01:00:00+02:00').where(delivered_at_gteq: '2026-10-01T00:30:00Z') }
    let(:shipments) { orm::Shipment.where(delivered_at: Time.utc(2026, 10, 1)..).where(delivered_at: later..) }

    it { expect(shipments.filter).to(eq(delivered_at_gteq: later)) }
    it { expect(offsets.filter).to(eq(delivered_at_gteq: '2026-10-01T00:30:00Z')) }
    it { expect(instants.filter).to(eq(delivered_at_eq: '2026-10-01T17:00:00-07:00')) }
    it { expect(orm::Shipment.where(id: 1, id_eq: 2)).to(be_empty) }
    it { expect(orm::Shipment.where(or: [{ id: 1, id_eq: 2 }, { pro: 'A' }]).filter).to(eq(or: [{ pro_eq: 'A' }])) }
    it { expect(dates.filter).to(eq(pickup_on_gteq: '2026-10-02')) }
    it { expect(orm::Shipment.where(pro_not_eq: 'A').where(pro_not_eq: 'B').filter).to(eq(pro_not_in: ['A', 'B'])) }
    it { expect(orm::Shipment.where(status: %i[booked delivered]).where(status: %i[delivered]).filter).to(eq(status_in: %i[delivered])) }
    it { expect(orm::Shipment.where(status: %i[booked delivered]).where(status: ['delivered']).filter).to(eq(status_in: %i[delivered])) }
    it { expect { orm::Shipment.where(pro_cont: 'A').where(pro_cont: 'B') }.to(raise_error(ArgumentError)) }
  end

  describe 'Shipment.where with nil' do
    it { expect(orm::Shipment.not(broker_carrier: nil).filter).to(eq(broker_carrier_id_null: false)) }
    it { expect(orm::Shipment.where(broker_carrier: nil, pro: nil).filter).to(eq(broker_carrier_id_null: true, pro_null: true)) }
  end

  describe 'Shipment#==' do
    let(:shipment) { orm::Shipment.new('1') }
    let(:untenanted) { FreightKit::Platforms::NextTMS::ORM::Shipment.new('1') }

    it { expect(orm::Shipment.new('01')).to(have_attributes(hash: shipment.hash, id: '1')) }
    it { expect(shipment).to(eq(orm::Shipment.new(1))) }
    it { expect(shipment).not_to(eq(untenanted)) }
    it { expect(untenanted).not_to(eq(shipment)) }
  end

  describe 'Shipment.where with zero-padded IDs' do
    it { expect(orm::Shipment.where(id: '012').filter).to(eq(id_eq: 12)) }
    it { expect(orm::Shipment.where(load_id: '001'...'010').filter).to(eq(load_id_gteq: 1, load_id_lt: 10)) }
  end

  describe 'Shipment.where with an array of records' do
    let(:broker_customers) { [orm::BrokerCustomer.new('4')] }

    before { orm::Shipment.where(broker_carrier: [orm::BrokerCarrier.new('12')]).not(broker_customer: broker_customers).first }

    it { expect(variables[:filter]).to(eq(broker_carrier_id_in: [12], broker_customer_id_not_in: [4])) }
  end

  describe 'Shipment.limit with Enumerable arguments' do
    subject(:shipments) { orm::Shipment.limit(1) }

    it { expect(shipments.any?(nil)).to(be(false)) }
    it { expect(shipments.any?(String)).to(be(false)) }
    it { expect(shipments.count(nil)).to(eq(0)) }
    it { expect(shipments.count { |shipment| shipment.status == :canceled }).to(eq(0)) }
  end

  describe 'Shipment.all without a limit' do
    let(:pages) do
      [1, 2].map do |page|
        items = [shipment.merge(id: page.to_s)]
        graphql_response(data: { shipments: { items:, page:, page_size: 100, pages: 2, total_items: 101, version: page.to_s } })
      end
    end

    before { allow(FreightKit::HTTPClient).to(receive(:request).and_return(*pages)) }

    it { expect(orm::Shipment.ids).to(eq(['1', '2'])) }
    it { expect(orm::Shipment.all.tap(&:to_a)).to(have_attributes(total_items: 101, version: '1')) }
  end

  describe 'Shipment.find_by!' do
    let(:data) { { shipment: shipment.except(:id).merge(id: '1234') } }

    before { orm::Shipment.find_by!(id: 1234) }

    it { expect(JSON.parse(carrier.last_request[:body], symbolize_names: true)[:query]).to(include('shipment(id: $id) {')) }
    it { expect(variables).to(eq(id: 1234)) }
  end

  describe 'Shipment.find_by! when missing' do
    let(:data) { { shipment: nil } }

    it { expect { orm::Shipment.find_by!(id: 1234) }.to(raise_error(FreightKit::Platforms::NextTMS::ORM::RecordNotFoundError)) }
  end

  describe 'Shipment' do
    subject(:record) { orm::Shipment.first }

    it { expect(record.broker_carrier).to(eq(orm::BrokerCarrier.new('12'))) }
    it { expect(record.delivered_at).to(eq(Time.utc(2026, 10, 30, 15))) }
    it { expect(record.delivery_eta_on).to(eq(Date.new(2026, 10, 30))) }
    it { expect(record.load_id).to(eq(1234)) }
    it { expect(record.receiver_address).to(be_nil) }
    it { expect(record.shipper_address).to(be_a(orm::Address)) }
    it { expect(record.shipper_address.to_location).to(have_attributes(city: 'Seattle', postal_code: '98101', province: 'WA')) }
    it { expect(record.status).to(eq(:delivered)) }
    it { expect(record.total_charges_cents).to(eq(50_000)) }
  end

  describe 'partial associations' do
    before { orm::Shipment.first.broker_carrier.carrier.scac }

    it { expect(FreightKit::HTTPClient).to(have_received(:request).once) }
  end

  describe 'lazy associations' do
    let(:data) { { broker_carrier: { account: 'ACCT', carrier: { id: '3' }, id: '12' } } }

    before { orm::BrokerCarrier.new('12').account }

    it { expect(JSON.parse(carrier.last_request[:body], symbolize_names: true)[:query]).to(include('brokerCarrier(id: $id) {')) }
    it { expect(variables).to(eq(id: '12')) }
  end
end
