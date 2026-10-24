# frozen_string_literal: true

module FreightKit
  class Country
    attr_reader :iso31661_alpha2, :iso31661_alpha3, :name, :un_code

    def initialize(iso31661_alpha2:, iso31661_alpha3:, name:, un_code: nil)
      @iso31661_alpha2 = iso31661_alpha2
      @iso31661_alpha3 = iso31661_alpha3
      @name = name
      @un_code = un_code
    end

    def ==(other) = other.is_a?(Country) && other.id == id
    alias_method :eql?, :==

    def hash = [self.class, id].hash
    def id = iso31661_alpha2
    def inspect = "#<#{self.class.name} #{iso31661_alpha2}>"
    def regions = FreightKit::Regions.all.select { |region| region.country == self }
  end
end
