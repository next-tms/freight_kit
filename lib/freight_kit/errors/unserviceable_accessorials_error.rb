# frozen_string_literal: true

module FreightKit
  class UnserviceableAccessorialsError < UnserviceableError
    attr_reader :accessorials

    def initialize(accessorials:)
      @accessorials = accessorials

      super(message)
    end

    def message
      @message ||= "Unable to service #{@accessorials.map do |accessorial|
                                          accessorial.to_s.gsub("_", " ")
                                        end.join(", ")}"
    end
  end
end
