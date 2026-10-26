require 'spec_helper'
require 'brotli'
require 'zstd-ruby'

describe FreightKit::HTTPClient do
  let(:json) { '{"ok":true}' }
  let(:requests) { Queue.new }
  let(:server) { TCPServer.new('127.0.0.1', 0) }
  # Expired on arrival, fresh again for a minute after each revalidation
  let(:stale_headers) { { 'Cache-Control' => 'max-age=60', 'Date' => 2.minutes.ago.httpdate, 'ETag' => '"v1"' } }
  let(:url) { "http://127.0.0.1:#{server.addr[1]}" }

  let(:responses) do
    {
      '/br' => [200, { 'Content-Encoding' => 'br', 'Content-Type' => 'application/json' }, Brotli.deflate(json)],
      '/empty' => [200, {}, ''],
      '/etag' => [200, { 'Cache-Control' => 'no-cache', 'Content-Type' => 'application/json', 'ETag' => '"v1"' }, json],
      '/fresh' => [200, stale_headers, json],
      '/xml' => [200, { 'Content-Type' => 'application/xml' }, '<a><b>1</b></a>'],
      '/zstd' => [200, { 'Content-Encoding' => 'zstd', 'Content-Type' => 'application/json' }, Zstd.compress(json)]
    }
  end

  # Lets are resolved up front: RSpec memoization locks would deadlock against the main thread
  let!(:thread) do
    requests = self.requests
    responses = self.responses
    server = self.server

    Thread.new do
      loop { serve(server.accept, requests:, responses:) }
    end
  end

  def serve(socket, requests:, responses:)
    path = socket.gets.split[1].split('?').first
    headers = {}
    while (line = socket.gets) != "\r\n"
      field, value = line.chomp.split(': ', 2)
      headers[field.downcase] = value
    end
    requests << headers

    # Unknown paths drop the connection without responding
    return socket.close unless responses.key?(path)

    status, response_headers, body = responses.fetch(path)
    if response_headers.key?('ETag') && headers['if-none-match'] == response_headers['ETag']
      body = ''
      response_headers = response_headers.merge('Date' => Time.now.httpdate)
      status = 304
    end

    socket.write("HTTP/1.1 #{status} OK\r\n")
    response_headers.merge('Connection' => 'close', 'Content-Length' => body.bytesize).each do |field, value|
      socket.write("#{field}: #{value}\r\n")
    end
    socket.write("\r\n#{body}")
    socket.close
  end

  before { described_class.cache = ActiveSupport::Cache::MemoryStore.new }

  after do
    thread.kill
    server.close
    described_class.cache = nil
    described_class.logger = nil
  end

  describe 'Accept-Encoding' do
    before { described_class.get("#{url}/br") }

    it { expect(requests.pop['accept-encoding'].split(/, */)).to(include('br', 'gzip', 'zstd')) }
  end

  describe 'User-Agent' do
    before { described_class.get("#{url}/br") }

    it { expect(requests.pop['user-agent']).to(eq("freight_kit/#{FreightKit::VERSION} httpx.rb/#{HTTPX::VERSION}")) }
  end

  describe 'decoding' do
    it { expect(described_class.get("#{url}/br").parsed_response).to(eq('ok' => true)) }
    it { expect(described_class.get("#{url}/zstd").parsed_response).to(eq('ok' => true)) }
    it { expect(described_class.get("#{url}/xml").dig('a', 'b')).to(eq('1')) }
    it { expect(described_class.get("#{url}/empty")).to(be_blank) }
  end

  describe 'conditional requests' do
    subject(:response) { described_class.get("#{url}/etag") }

    before do
      described_class.get("#{url}/etag")
      response
      requests.pop
    end

    it { expect(requests.pop['if-none-match']).to(eq('"v1"')) }
    it { expect(response.code).to(eq(200)) }
    it { expect(response.parsed_response).to(eq('ok' => true)) }
  end

  describe 'freshness renewed by revalidation' do
    before { 3.times { described_class.get("#{url}/fresh") } }

    it { expect(requests.size).to(eq(2)) }
  end

  describe 'cache' do
    let(:cache) { ActiveSupport::Cache::MemoryStore.new }

    before do
      described_class.cache = cache
      described_class.get("#{url}/etag")
    end

    it { expect(cache.instance_variable_get(:@data).keys).to(all(start_with('freight_kit/http_client/'))) }

    context 'with different credentials' do
      before do
        requests.pop
        described_class.get("#{url}/etag", headers: { Authorization: 'Bearer a' })
        described_class.get("#{url}/etag", headers: { Authorization: 'Bearer b' })
        requests.pop
      end

      it { expect(requests.pop).not_to(have_key('if-none-match')) }
    end

    context 'with different query parameters' do
      before do
        requests.pop
        described_class.get("#{url}/etag", query: { ReferenceNum: 1 })
        described_class.get("#{url}/etag", query: { ReferenceNum: 2 })
        requests.pop
      end

      it { expect(requests.pop).not_to(have_key('if-none-match')) }
    end

    context 'when cleared' do
      before { described_class::CacheStore.new(cache).clear }

      it { expect(cache.instance_variable_get(:@data)).to(be_empty) }
    end

    context 'with Redis' do
      let(:redis) { instance_double(ActiveSupport::Cache::Store) }

      before do
        allow(redis).to(receive(:delete_matched).with(Regexp).and_raise(ArgumentError))
        allow(redis).to(receive(:delete_matched).with(String))
        described_class::CacheStore.new(redis).clear
      end

      it { expect(redis).to(have_received(:delete_matched).with('freight_kit/http_client/*')) }
    end
  end

  describe 'retries' do
    let(:verb) { :get }

    before do
      described_class.request(verb, "#{url}/reset")
    rescue StandardError
      nil
    end

    it { expect(requests.size).to(eq(2)) }

    context 'with a POST' do
      let(:verb) { :post }

      it { expect(requests.size).to(eq(1)) }
    end
  end

  describe 'logging' do
    subject(:get) { described_class.get("#{url}/xml") }

    let(:log) { StringIO.new }
    let(:logger) { Logger.new(log, level: :debug) }

    it { expect { get }.not_to(output.to_stdout) }

    context 'with LOG_LEVEL=debug' do
      before { stub_const('ENV', ENV.to_h.merge('LOG_LEVEL' => 'debug')) }

      it { expect { get }.to(output(%r{GET /xml}).to_stdout) }
    end

    context 'with a logger' do
      before do
        described_class.logger = logger
        get
      end

      it { expect(log.string).to(match(%r{DEBUG -- : .*GET /xml})) }
    end

    context 'with an info logger' do
      before do
        described_class.logger = Logger.new(log, level: :info)
        get
      end

      it { expect(log.string).to(be_empty) }
    end

    context 'with Rails' do
      before do
        stub_const('Rails', Module.new)
        allow(Rails).to(receive(:logger).and_return(logger))
        get
      end

      it { expect(log.string).to(match(%r{GET /xml})) }
    end

    context 'with Hanami' do
      before do
        stub_const('Hanami', Module.new)
        allow(Hanami).to(receive_messages(app: { 'logger' => logger }, app?: true))
        get
      end

      it { expect(log.string).to(match(%r{GET /xml})) }
    end
  end
end
