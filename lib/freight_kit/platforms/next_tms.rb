module FreightKit
  module Platforms
    class NextTMS < Platform
      class << self
        def required_credential_types = %i[api]
      end

      API = {
        endpoints: { authenticate: '/authenticate', show: '/shipments' },
        methods: { authenticate: :post, show: :get },
        prefix: '/api/v1',
        scopes: { broker: '/broker', customer: '/customer' },
        use_ssl: true
      }.freeze
      JSON_HEADERS = { Accept: 'application/json', 'Content-Type': 'application/json', charset: 'utf-8' }.freeze

      # Documents

      # Rates

      def base_url
        api = self.class::API
        "https://#{api[:domain]}#{api[:prefix]}#{api.dig(:scope, @options[:scope])}"
      end

      def build_request(action, options = {})
        headers = JSON_HEADERS
        headers = headers.merge(options[:headers]) if options[:headers].present?
        body = options[:body].to_json if options[:body].present?

        unless action == :authenticate
          set_auth_token
          headers = headers.merge(token)
        end

        request = { url: build_url(action, options), headers:, method: self.class::API.dig(:methods, action), body: }

        save_request(request)
        request
      end

      def build_url(action, options = {})
        endpoint = self.class::API.dig(:endpoints, action)
        scope = self.class::API.dig(:scopes, options[:scope])

        url = ''.dup
        url += "#{base_url}#{scope}#{endpoint}"
        url = url.sub(scope, '') if action == :authenticate
        url += options[:params] if options[:params].present?
        url
      end

      def commit(request)
        url = request[:url]
        headers = request[:headers]
        method = request[:method]
        body = request[:body]

        response = case method
                   when :post
                     HTTPClient.post(url, headers:, body:)
                   else
                     HTTPClient.get(url, headers:)
                   end

        JSON.parse(response.body) if response&.body
      end

      def set_auth_token
        return @auth_token if @auth_token.present?

        api_credentials = fetch_credential(:api)

        request = build_request(
          :authenticate,
          body: { email: api_credentials.username, password: api_credentials.password }
        )

        response = commit(request)
        @auth_token = response['auth_token']
      end

      def show(id)
        request = build_request(:show, params: "/#{id}")
        commit(request)
      end

      def token = { Authorization: "Bearer #{@auth_token}" }

      # Show
    end
  end
end
