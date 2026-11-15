require 'spec_helper'

describe FreightKit::SoapClient do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:fixtures) { File.expand_path('../fixtures/soap_client', __dir__) }
  let(:keys) { cache.instance_variable_get(:@data).keys }
  let(:server) { TestServer.new }
  let(:wsdl_headers) { { 'Content-Type' => 'text/xml' } }
  let(:wsdl_url) { "#{server.url}/wsdl" }

  let(:soap_client) do
    described_class.new(
      action: :rates,
      call_args: { message: {} },
      carrier: nil,
      client_args: { wsdl: wsdl_url },
      soap_operation: :get_quote
    )
  end

  before do
    FreightKit.cache = cache

    # Gzipped so that HTTPI would fail decoding the body again
    server.responses = {
      '/soap' => [
        200,
        { 'Content-Encoding' => 'gzip', 'Content-Type' => 'text/xml' },
        ActiveSupport::Gzip.compress(File.read("#{fixtures}/get_quote_response.xml"))
      ],
      '/wsdl' => [200, wsdl_headers, format(File.read("#{fixtures}/quote.wsdl"), url: server.url)]
    }
  end

  after do
    FreightKit.cache = nil
    server.close
  end

  describe '.call' do
    subject(:response) { soap_client.call }

    before { response }

    it { expect(response).to(eq(get_quote_response: { rate: '1' })) }
    it { expect(server.requests.map(&:path)).to(eq(['/wsdl', '/soap'])) }
    it { expect(server.requests.map { |request| request.headers['user-agent'] }).to(all(start_with('freight_kit/'))) }

    context 'when called again' do
      before { soap_client.call }

      it { expect(keys).to(include(start_with('freight_kit/http_client/'))) }
      it { expect(keys).to(include(start_with('freight_kit/soap_client/wsdl/'))) }
      it { expect(server.requests.map(&:path)).to(eq(['/wsdl', '/soap', '/soap'])) }

      context 'with an ETag' do
        let(:wsdl_headers) { { 'Cache-Control' => 'no-cache', 'Content-Type' => 'text/xml', 'ETag' => '"v1"' } }

        it { expect(keys).not_to(include(start_with('freight_kit/soap_client/wsdl/'))) }
        it { expect(server.requests[2].headers['if-none-match']).to(eq('"v1"')) }
        it { expect(server.requests.map(&:path)).to(eq(['/wsdl', '/soap', '/wsdl', '/soap'])) }
      end

      context 'with a max-age' do
        let(:wsdl_headers) { { 'Cache-Control' => 'max-age=60', 'Content-Type' => 'text/xml' } }

        it { expect(keys).not_to(include(start_with('freight_kit/soap_client/wsdl/'))) }
        it { expect(server.requests.map(&:path)).to(eq(['/wsdl', '/soap', '/soap'])) }
      end
    end

    context 'when the server is unreachable' do
      let(:wsdl_url) { 'http://127.0.0.1:1/wsdl' }

      it { expect(response.error.message).to(start_with('Network Error: ')) }
    end
  end
end
