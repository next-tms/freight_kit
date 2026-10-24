# frozen_string_literal: true

module FreightKit
  module Countries
    extend self

    def all
      @all ||= ISO3166::Country
               .all
               .map do |iso_country|
                 Country.new(
                   iso31661_alpha2: iso_country.alpha2,
                   iso31661_alpha3: iso_country.alpha3,
                   name: iso_country.iso_short_name,
                   un_code: iso_country.number&.to_i,
                 )
               end
    end

    def find_by(**attributes)
      all.find { |country| attributes.all? { |key, value| country.public_send(key) == value } }
    end
  end
end
