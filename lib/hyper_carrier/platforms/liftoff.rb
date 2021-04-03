# frozen_string_literal: true

module ReactiveShipping
  class Liftoff < ReactiveShipping::Platform
    REACTIVE_FREIGHT_CARRIER = true

    JSON_HEADERS = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'charset': 'utf-8'
    }.freeze

    def requirements
      %i[email password scope]
    end

    # Documents

    # Rates

    def show(id)
      request = build_request(:show, params: "/#{id}")
      commit(request)
    end

    # Tracking

    # protected

    def build_url(action, options = {})
      options = @options.merge(options)
      url = ''.dup
      url += "#{base_url}#{@conf.dig(:api, :scopes, options[:scope])}#{@conf.dig(:api, :endpoints, action)}"
      url = url.sub(@conf.dig(:api, :scopes, options[:scope]), '') if action == :authenticate
      url += options[:params] unless options[:params].blank?
      url
    end

    def build_request(action, options = {})
      options = @options.merge(options)
      headers = JSON_HEADERS
      headers = headers.merge(options[:headers]) unless options[:headers].blank?
      body = options[:body].to_json unless options[:body].blank?

      unless action == :authenticate
        set_auth_token
        headers = headers.merge(token)
      end

      request = {
        url: build_url(action, options),
        headers: headers,
        method: @conf.dig(:api, :methods, action),
        body: body
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
                   HTTParty.post(url, headers: headers, body: body)
                 else
                   HTTParty.get(url, headers: headers)
                 end

      JSON.parse(response.body) if response&.body
    end

    def base_url
      "https://#{@conf.dig(:api, :domain)}#{@conf.dig(:api, :prefix)}#{@conf.dig(:api, :scope, @options[:scope])}"
    end

    def set_auth_token
      return @auth_token unless @auth_token.blank?

      request = build_request(
        :authenticate,
        body: {
          email: @options[:email],
          password: @options[:password]
        }
      )

      response = commit(request)
      @auth_token = response.dig('auth_token')
    end

    def token
      { 'Authorization': "Bearer #{@auth_token}" }
    end

    # Show
  end
end
