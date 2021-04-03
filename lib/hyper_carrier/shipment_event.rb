module HyperCarrier
  class ShipmentEvent
    attr_reader :name, :time, :location, :message, :type_code

    def initialize(name, time, location, message = nil, type_code = nil)
      @name, @time, @location, @message, @type_code = name, time, location, message, type_code
    end

    def delivered?
      status == :delivered
    end

    # Return symbol of status rather than a string but maintain compatibility with ReactiveShipping
    def status
      @status ||= name.class == String ? name.downcase.gsub("\s", '_').to_sym : name
    end

    def ==(other)
      attributes = %i(name time location message type_code)
      attributes.all? { |attr| self.public_send(attr) == other.public_send(attr) }
    end
  end
end
