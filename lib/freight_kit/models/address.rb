# frozen_string_literal: true

module FreightKit
  # Class representing a real, deliverable mailing address.
  class Address < Model
    attr_accessor :city, :postal_code, :region_abbreviation, :street, :street2
    attr_reader :country

    def country=(country)
      return @country = nil if country.blank?

      raise ArgumentError, 'country must be a FreightKit::Country' unless country.is_a?(Country)

      @country = country
    end
  end
end
