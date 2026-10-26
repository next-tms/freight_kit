module FreightKit
  class Region
    attr_reader :abbreviation, :country, :iso31662, :name

    def initialize(abbreviation:, country:, iso31662:, name:)
      @abbreviation = abbreviation
      @country = country
      @iso31662 = iso31662
      @name = name
    end

    def ==(other) = other.is_a?(Region) && other.id == id
    alias eql? ==

    def hash = [self.class, id].hash
    def id = iso31662
    def inspect = "#<#{self.class.name} #{iso31662}>"
  end
end
