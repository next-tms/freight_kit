module FreightKit
  # Class representing a location.
  #
  # @attribute address1
  #   The first street line
  #   @return [String, nil]
  #
  # @attribute address2
  #   The second street line
  #   @return [String, nil]
  #
  # @attribute address3
  #   The third street line
  #   @return [String, nil]
  #
  # @attribute city
  #   The city name.
  #   @return [String, nil]
  #
  # @attribute contact
  #   The contact at the location.
  #   @return [String, nil]
  #
  # @attribute country
  #   The country of the location.
  #   @return [ActiveUtils::Country, nil]
  #
  # @attribute lat
  #   The latitude of the location.
  #   @return [BigNum, nil]
  #
  # @attribute lng
  #   The longitude of the location.
  #   @return [BigNum, nil]
  #
  # @attribute postal_code
  #   The postal code (or ZIP® code) of the location.
  #   @return [String, nil]
  #
  # @attribute province
  #   The province (or state/territory) abbreviation of the location.
  #   @return [String, nil]
  #
  # @attribute type
  #   The type of the location.
  #
  #   It should be one of: :commercial, :po_box, :residential
  #
  #   @return [Symbol, nil]
  #
  class Location < Model
    TYPES = %i[commercial po_box residential].freeze

    attr_accessor :address1, :address2, :address3, :city, :postal_code, :province
    attr_reader :contact, :country, :lat, :lng, :type

    def contact=(contact)
      raise ArgumentError, 'contact must be a Contact' unless contact.blank? || contact.is_a?(FreightKit::Contact)

      @contact = contact.presence
    end

    def country=(country)
      raise ArgumentError, 'country must be an ActiveUtils::Country' unless country.blank? || country.is_a?(ActiveUtils::Country)

      @country = country.presence
    end

    def lat=(num)
      raise ArgumentError, 'lat must be a BigNum' unless num.blank? || num.is_a?(BigNum)

      @lat = num.presence
    end

    def lng=(num)
      raise ArgumentError, 'lng must be a BigNum' unless num.blank? || num.is_a?(BigNum)

      @lng = num.presence
    end

    def time_zone
      return if country&.code(:alpha2)&.blank? || province.blank? || city.blank?

      PlaceKit.lookup(country.code(:alpha2).to_s, province, city)
    end

    def type=(value)
      raise ArgumentError, "type must be one of :#{TYPES.join(', :')}" unless value.blank? || TYPES.include?(value)

      @type = value.presence
    end
  end
end
