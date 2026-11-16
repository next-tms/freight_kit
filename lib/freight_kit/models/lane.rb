module FreightKit
  # Class representing a carrier's service in one direction, from one territory to another.
  #
  # @!attribute destination [FreightKit::Territory] Where the carrier delivers.
  # @!attribute id [String] Permanent UUID. Applications store it, so never change it.
  # @!attribute origin [FreightKit::Territory] Where the carrier picks up.
  class Lane < Model
    attr_accessor :destination, :id, :origin

    # Whether the lane goes from the origin to the destination.
    # @param destination [FreightKit::Location]
    # @param origin [FreightKit::Location]
    # @return [Boolean]
    def include?(origin, destination) = self.origin.include?(origin) && self.destination.include?(destination)

    # How narrow the lane is: the sum of its territories' specificity.
    # @return [Integer]
    def specificity = origin.specificity + destination.specificity
  end
end
