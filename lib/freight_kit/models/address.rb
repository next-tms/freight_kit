module FreightKit
  # Class representing a real, deliverable mailing address.
  #
  # @!attribute id [String, nil] Permanent UUID of a carrier's address. Applications store it, so never change it.
  class Address < Model
    attr_accessor :city, :id, :postal_code, :region_abbreviation, :street, :street2
    attr_reader :country

    def country=(country)
      raise ArgumentError, 'country must be a FreightKit::Country' unless country.blank? || country.is_a?(Country)

      @country = country.presence
    end
  end
end
