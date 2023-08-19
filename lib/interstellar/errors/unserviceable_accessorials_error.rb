# frozen_string_literal: true

module Interstellar
  class UnserviceableAccessorialsError < Interstellar::UnserviceableError
    attr_reader :accessorials

    def initialize(accessorials:)
      @accessorials = accessorials

      super(message)
    end

    def message
      @message ||= "Unable to service #{@accessorials.map { |accessorial| accessorial.to_s.gsub("_", " ") }.join(", ")}"
    end
  end
end
