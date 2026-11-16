module FreightKit
  # Class representing an area a carrier serves. A blank attribute matches any location.
  #
  # @!attribute country [FreightKit::Country] Country.
  # @!attribute postal_codes [Array<String>] Postal codes or their prefixes (e.g. "850").
  # @!attribute region_abbreviation [String, nil] Region (state or province) abbreviation, e.g. "CA".
  class Territory < Model
    attr_accessor :region_abbreviation
    attr_reader :country

    def country=(country)
      raise ArgumentError, 'country must be a FreightKit::Country' unless country.is_a?(Country)

      @country = country
    end

    # Whether the location is inside the territory.
    # @param location [FreightKit::Location]
    # @return [Boolean]
    def include?(location)
      return false unless location.country&.code(:alpha2)&.to_s == country.iso31661_alpha2
      return false if region_abbreviation.present? && location.province != region_abbreviation

      postal_codes.blank? || postal_codes.any? { |postal_code| location.postal_code.to_s.start_with?(postal_code) }
    end

    def postal_codes = @postal_codes || []

    def postal_codes=(postal_codes)
      @postal_codes = Array.wrap(postal_codes)
    end

    # How narrow the territory is: 0 for a country, 1 for a region, 2 for postal codes.
    # @return [Integer]
    def specificity = [region_abbreviation, postal_codes].count(&:present?)
  end
end
