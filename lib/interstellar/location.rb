# frozen_string_literal: true

module Interstellar # :nodoc:
  class Location
    ADDRESS_TYPES = %w[residential commercial po_box].freeze

    ATTRIBUTE_ALIASES = {
      address_type: %i[address_type],
      address1: %i[address1 address street],
      address2: %i[address2],
      address3: %i[address3],
      city: %i[city town],
      company_name: %i[company company_name],
      country: %i[country_code country],
      postal_code: %i[postal_code zip postal],
      province: %i[province_code state_code territory_code region_code province state territory region]
    }.freeze

    alias postal postal_code
    alias region province
    alias state province
    alias territory province
    alias zip postal_code

    attr_accessor :contact,
                  :country,
                  :postal_code,
                  :province,
                  :city,
                  :address1,
                  :address2,
                  :address3

    attr_reader :address_type

    def initialize(options = {})
      @country = if options[:country].nil? || options[:country].is_a?(ActiveUtils::Country)
                   options[:country]
                 else
                   ActiveUtils::Country.find(options[:country])
                 end

      @contact = if options[:contact].is_a?(Interstellar::Contact)
                   options[:contact]
                 elsif options[:contact_attributes].is_a?(Hash)
                   Interstellar::Contact.new(options[:contact_attributes])
                 end

      @postal_code = options[:postal_code] || options[:postal] || options[:zip]
      @province = options[:province] || options[:state] || options[:territory] || options[:region]
      @city = options[:city]
      @address1 = options[:address1]
      @address2 = options[:address2]
      @address3 = options[:address3]

      self.address_type = options[:address_type]
    end

    def self.from(object, options = {})
      return object if object.is_a?(Location)

      attributes = {}

      hash_access = object.respond_to?(:[])

      ATTRIBUTE_ALIASES.each do |attribute, aliases|
        aliases.detect do |sym|
          value = object[sym] if hash_access
          if !value &&
             object.respond_to?(sym) &&
             (!hash_access || !Hash.public_instance_methods.include?(sym))
            value = object.send(sym)
          end

          attributes[attribute] = value if value
        end
      end

      attributes.delete(:address_type) unless ADDRESS_TYPES.include?(attributes[:address_type].to_s)

      new(attributes.update(options))
    end

    def country_code(format = :alpha2)
      @country.nil? ? nil : @country.code(format).value
    end

    def residential?
      @address_type == 'residential'
    end

    def commercial?
      @address_type == 'commercial'
    end

    def po_box?
      @address_type == 'po_box'
    end

    def unknown?
      country_code == 'ZZ'
    end

    def address_type=(value)
      return unless value.present?
      unless ADDRESS_TYPES.include?(value.to_s)
        raise ArgumentError, "address_type must be one of #{ADDRESS_TYPES.join(', ')}"
      end

      @address_type = value.to_s
    end

    def to_hash
      {
        country: country_code,
        postal_code: postal_code,
        province: province,
        city: city,
        address1: address1,
        address2: address2,
        address3: address3,
        address_type: address_type
      }
    end

    def to_s
      prettyprint.gsub(/\n/, ' ')
    end

    def prettyprint
      chunks = [@address1, @address2, @address3]
      chunks << [@city, @province, @postal_code].reject(&:blank?).join(', ')
      chunks << @country
      chunks.reject(&:blank?).join("\n")
    end

    # Returns the postal code as a properly formatted Zip+4 code, e.g. "77095-2233"
    def zip_plus_4
      "#{Regexp.last_match(1)}-#{Regexp.last_match(2)}" if /(\d{5})-?(\d{4})/ =~ @postal_code
    end

    def address2_and_3
      [address2, address3].reject(&:blank?).join(', ')
    end

    def ==(other)
      to_hash == other.to_hash
    end
  end
end
