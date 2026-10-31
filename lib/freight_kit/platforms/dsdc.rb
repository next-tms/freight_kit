module FreightKit
  module Platforms
    # Carriers whose APIs follow the NMFTA Digital Standards Development Council (DSDC) LTL API standards.
    #
    # The standards define paths and payloads but not hosts or authentication, so subclasses set `API[:domain]`
    # (and `API[:prefix]` if the carrier mounts the APIs under one) and implement {#authorization_headers}.
    #
    # @see https://dsdc.nmfta.org/apis
    # @see https://github.com/dsdcapis/less-than-truckload/tree/main/api-specs
    class DSDC < Platform
      class << self
        def required_credential_types = %i[api]
      end

      API = {
        endpoints: {
          # eBOL 2.1.0
          cancel_bol: '/bol/v1/app/%<pro>s',
          create_bol: '/bol/v1/app/',
          update_bol: '/bol/v1/app/%<pro>s',
          # Pickup Request and Visibility 1.0.0
          cancel_pickup: '/v1/pickups/%<pickup_id>s',
          create_pickup: '/v1/pickups/',
          show_pickup: '/v1/pickups/',
          update_pickup: '/v1/pickups/%<pickup_id>s',
          # In-Transit Visibility 1.0.0
          track: '/shipment/pro/%<pro>s/verified'
        },
        methods: {
          cancel_bol: :delete,
          cancel_pickup: :delete,
          create_bol: :post,
          create_pickup: :post,
          show_pickup: :get,
          track: :get,
          update_bol: :put,
          update_pickup: :put
        },
        use_ssl: true
      }.freeze
      JSON_HEADERS = { Accept: 'application/json', 'Content-Type': 'application/json' }.freeze

      protected

      # @return [Hash] Headers that authenticate requests, e.g. a bearer token or API key.
      def authorization_headers = raise NotImplementedError, "#{name}: #authorization_headers not implemented"

      # @param action [Symbol] A key of `API[:endpoints]`.
      # @param body [Hash, nil] Payload, sent as JSON.
      # @param query [Hash, nil] Query parameters, e.g. `lookupType` and `lookupValue` for `:show_pickup`.
      # @param path_params [Hash] Values for the endpoint's placeholders, e.g. `pro:`.
      def build_request(action, body: nil, query: nil, **path_params)
        request = {
          body: body&.to_json,
          headers: JSON_HEADERS.merge(authorization_headers),
          method: self.class::API.dig(:methods, action),
          query:,
          url: build_url(action, **path_params)
        }

        save_request(request)
        request
      end

      def build_url(action, **path_params)
        api = self.class::API
        endpoint = format(api.dig(:endpoints, action), **path_params.transform_values { |value| ERB::Util.url_encode(value.to_s) })

        "#{api[:use_ssl] ? 'https' : 'http'}://#{api[:domain]}#{api[:prefix]}#{endpoint}"
      end

      def commit(request)
        response = HTTPClient.request(request[:method], request[:url], **request.slice(:body, :headers, :query))

        raise InvalidCredentialsError, "HTTP #{response.code}: #{response}" if [401, 403].include?(response.code)
        raise HTTPError.new(body: response.body, code: response.code) unless (200..299).cover?(response.code)

        response.parsed_response
      end
    end
  end
end
