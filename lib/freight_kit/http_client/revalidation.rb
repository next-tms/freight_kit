module FreightKit
  class HTTPClient
    # HTTPX plugin making revalidated (304 Not Modified) responses look like the cached
    # response they were revalidated against, so callers checking for 200 keep working.
    #
    # HTTPX renews freshness by mutating the cached response in memory, which serializing
    # cache stores never see, so the refreshed response is stored again.
    module Revalidation
      module ResponseMethods
        def copy_from_cached!
          super
          return unless (cached_response = @request.cached_response)

          @status = cached_response.status
          store = @request.options.response_cache_store
          store.set(@request, self) if HTTPX::Plugins::ResponseCache.cacheable_response?(self)
        end
      end

      class << self
        def load_dependencies(klass) = klass.plugin(:response_cache)
      end
    end
  end
end
