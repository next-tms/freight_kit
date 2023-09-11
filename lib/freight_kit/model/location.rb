# frozen_string_literal: true

module FreightKit
  module Model
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
    class Location < Base
      TYPES = %i[commercial po_box residential].freeze

      attr_accessor :address1, :address2, :address3, :city, :postal_code, :province
      attr_reader :contact, :country, :lat, :lng, :type

      def contact=(contact)
        return @contact = nil if contact.blank?

        raise ArgumentError, 'contact must be a Contact' unless contact.is_a?(FreightKit::Contact)

        @contact = contact
      end

      def country=(country)
        return country = nil if country.blank?

        if country.is_a?(ActiveUtils::Country)
          @country = country
          return country
        end

        raise ArgumentError, 'country must be an ActiveUtils::Country'
      end

      def lat=(num)
        return @lat = nil if num.blank?

        return @lat = num if num.is_a?(BigNum)

        raise ArgumentError, 'lat must be a BigNum'
      end

      def lng=(num)
        return @lng = nil if num.blank?

        return @lng = num if num.is_a?(BigNum)

        raise ArgumentError, 'lng must be a BigNum'
      end

      def time_zone
        return if country&.code(:alpha2)&.blank? || province.blank? || city.blank?

        PlaceKit.lookup(country.code(:alpha2).to_s, province, city)
      end

      def type=(value)
        return @type = nil if value.blank?

        raise ArgumentError, "type must be one of :#{TYPES.join(", :")}" unless TYPES.include?(value)

        @type = value
      end
    end
  end
end
