module FreightKit
  module Regions
    module_function

    def all
      locale = I18n.locale

      (@all ||= {})[locale] ||= ISO3166::Country
                                .all
                                .flat_map do |iso_country|
                                  country = Countries.find_by(iso31661_alpha2: iso_country.alpha2)

                                  iso_country
                                    .subdivisions.map do |abbreviation, subdivision|
                                    Region.new(
                                      abbreviation:,
                                      country:,
                                      iso31662: "#{iso_country.alpha2}-#{abbreviation}",
                                      name: subdivision.translations[locale] || subdivision.name
                                    )
                                  end
                                end
    end

    def find_by(**attributes) = all.find { |region| attributes.all? { |key, value| region.public_send(key) == value } }
  end
end
