# frozen_string_literal: true

module FreightKit
  # Normalizes US street addresses for comparison, using the StreetAddress gem's
  # direction and street type tables.
  class AddressNormalizer
    UNIT_DESIGNATORS = ['apt', 'bldg', 'building', 'dept', 'fl', 'floor', 'rm', 'room', 'ste', 'suite', 'unit'].freeze

    class << self
      # Normalizes a street line so that, for example, "22205 E. 19th Ave." and
      # "22205 East 19th Avenue" both become "22205 e 19th ave".
      #
      # @param address1 [String, nil]
      # @return [String, nil]
      def street_key(address1)
        return if address1.blank?

        words = address1.split('#').first.to_s.downcase.delete('.').gsub(/[^a-z0-9\s]/, ' ').split
        words = words.take_while { |word| UNIT_DESIGNATORS.exclude?(word) }
        return unless words.first&.match?(/\d/)

        words.map do |word|
          StreetAddress::US::DIRECTIONAL[word]&.downcase || StreetAddress::US::STREET_TYPES[word] || word
        end.join(' ')
      end
    end
  end
end
