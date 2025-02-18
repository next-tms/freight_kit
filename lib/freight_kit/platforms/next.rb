# frozen_string_literal: true

module FreightKit
  class Next < Platform
    class << self
      def required_credential_types
        %i[api]
      end
    end

    REACTIVE_FREIGHT_PLATFORM = true

    JSON_HEADERS = {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      charset: 'utf-8'
    }.freeze

    # Documents

    # Rates

    def show(id)
      request = build_request(:show, params: "/#{id}")
      commit(request)
    end

    # Tracking

    # protected

    def build_url(action, options = {})
      url = ''.dup
      url += "#{base_url}#{@conf.dig(:api, :scopes, options[:scope])}#{@conf.dig(:api, :endpoints, action)}"
      url = url.sub(@conf.dig(:api, :scopes, options[:scope]), '') if action == :authenticate
      url += options[:params] if options[:params].present?
      url
    end

    def build_request(action, options = {})
      headers = JSON_HEADERS
      headers = headers.merge(options[:headers]) if options[:headers].present?
      body = options[:body].to_json if options[:body].present?

      unless action == :authenticate
        set_auth_token
        headers = headers.merge(token)
      end

      request = {
        url: build_url(action, options),
        headers:,
        method: @conf.dig(:api, :methods, action),
        body:
      }

      save_request(request)
      request
    end

    def commit(request)
      url = request[:url]
      headers = request[:headers]
      method = request[:method]
      body = request[:body]

      response = case method
                 when :post
                   HTTParty.post(url, headers:, body:)
                 else
                   HTTParty.get(url, headers:)
                 end

      JSON.parse(response.body) if response&.body
    end

    def base_url
      "https://#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :prefix)}#{@conf.dig(:api, :scope, @options[:scope])}"
    end

    def set_auth_token
      return @auth_token if @auth_token.present?

      api_credentials = fetch_credential(:api)

      request = build_request(
        :authenticate,
        body: { email: api_credentials.username, password: api_credentials.password },
      )

      response = commit(request)
      @auth_token = response['auth_token']
    end

    def token
      { Authorization: "Bearer #{@auth_token}" }
    end

    # Show
  end
end
