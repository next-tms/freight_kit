module FreightKit
  module Platforms
    class NextTMS
      module ORM
        # Embedded in other records, so it has no query of its own and is always loaded.
        class Address < Base
          def city = @city ||= attribute(:city)
          def country = @country ||= attribute(:country)&.dig(:alpha2_code)&.then { |code| ActiveUtils::Country.find(code) }
          def loaded? = true
          def region = @region ||= attribute(:region)&.dig(:abbreviation)
          def street = @street ||= attribute(:street)
          def street2 = @street2 ||= attribute(:street2)
          def time_zone_name = @time_zone_name ||= attribute(:time_zone_name)

          def to_location = Location.new(address1: street, address2: street2, city:, country:, postal_code: zip_code, province: region)

          def zip_code = @zip_code ||= attribute(:zip_code)
        end
      end
    end
  end
end
