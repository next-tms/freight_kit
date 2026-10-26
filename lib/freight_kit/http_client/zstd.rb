module FreightKit
  class HTTPClient
    # HTTPX plugin decoding Zstandard ("zstd") response bodies, modeled on HTTPX's brotli plugin.
    module Zstd
      class Inflater
        def initialize = @inflater = ::Zstd::StreamingDecompress.new

        def call(chunk) = @inflater.decompress(chunk)
      end

      module ResponseBodyClassMethods
        def initialize_inflater_by_encoding(encoding, response, **) = encoding == 'zstd' ? Inflater.new : super
      end

      class << self
        def extra_options(options)
          supported_compression_formats = (['zstd'] + options.supported_compression_formats).freeze

          headers = options.headers.merge('accept-encoding' => supported_compression_formats)

          options.merge(headers: options.headers_class.new(headers), supported_compression_formats:)
        end

        def load_dependencies(*) = require('zstd-ruby')
      end
    end
  end
end
