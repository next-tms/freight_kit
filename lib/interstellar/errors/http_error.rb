# frozen_string_literal: true

module Interstellar
  class HTTPError < Interstellar::Error
    attr_reader :body, :code

    def initialize(body:, code:)
      @body = body
      @code = code
    end

    def message
      return @message if @message

      @message = "HTTP error (#{@code})"
      @message += ": #{@body}" unless @body.blank?
      @message
    end

    def to_s
      message
    end

    def to_hash
      @to_hash ||= { code: @http.code, headers: @http.headers, body: @http.body }
    end
  end
end
