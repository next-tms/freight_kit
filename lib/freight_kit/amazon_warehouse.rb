module FreightKit
  # Amazon warehouses in the United States, from OpenStreetMap.
  #
  # Regenerate the list with `rake amazon_warehouses:update`.
  module AmazonWarehouse
    extend self

    def all
      @all ||= YAML.safe_load_file(
        File.expand_path('../../configuration/locations/amazon_warehouses.yml', __dir__),
        permitted_classes: [Symbol]
      )
    end

    # @param location [Location]
    # @return [Hash, nil] The warehouse at the location, if any.
    def find(location)
      postal_code = location&.postal_code&.[](/\A\d{5}/)
      return if postal_code.blank?

      street_key = AddressNormalizer.street_key(location.address1)
      return if street_key.blank?

      by_postal_code[postal_code]&.find { |warehouse| warehouse[:street_key] == street_key }
    end

    def include?(location) = find(location).present?

    private

    def by_postal_code = @by_postal_code ||= all.group_by { |warehouse| warehouse[:postal_code] }
  end
end
