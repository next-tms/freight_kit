# Serves canned responses (path => [status, headers, body]) from a local port and records each request.
# Unknown paths drop the connection without responding.
class TestServer
  Request = Data.define(:headers, :path)

  attr_accessor :responses

  def initialize
    @mutex = Mutex.new
    @requests = []
    @responses = {}
    @server = TCPServer.new('127.0.0.1', 0)
    @thread = Thread.new { loop { serve(@server.accept) } }
  end

  def close
    @thread.kill
    @server.close
  end

  def requests = @mutex.synchronize { @requests.dup }
  def url = "http://127.0.0.1:#{@server.addr[1]}"

  private

  def read_headers(socket)
    headers = {}
    while (line = socket.gets) != "\r\n"
      field, value = line.chomp.split(': ', 2)
      headers[field.downcase] = value
    end
    headers
  end

  def serve(socket)
    path = socket.gets.split[1]
    headers = read_headers(socket)
    socket.read(headers['content-length'].to_i) if headers.key?('content-length')
    @mutex.synchronize { @requests << Request.new(headers:, path:) }

    return socket.close unless responses.key?(path)

    status, response_headers, body = responses.fetch(path)
    socket.write("HTTP/1.1 #{status} OK\r\n")
    response_headers.merge('Connection' => 'close', 'Content-Length' => body.bytesize).each do |field, value|
      socket.write("#{field}: #{value}\r\n")
    end
    socket.write("\r\n#{body}")
    socket.close
  end
end
