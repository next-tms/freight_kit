module FreightKit
  # Class representing where a carrier picks up and delivers within one country. A shipment point is in the area when
  # its postal code is in {#postal_codes}, or its region is in {#regions}.
  #
  # @!attribute country [FreightKit::Country] Country that the postal codes and regions belong to.
  # @!attribute id [String] Permanent UUID. Applications store it, so never change it.
  # @!attribute postal_codes [Array<String>] Postal codes served, for regions only partly served.
  # @!attribute regions [Array<FreightKit::Region>] Regions served whole.
  class ServiceArea < Model
    attr_accessor :id, :postal_codes, :regions
    attr_reader :country

    def initialize(attributes = {})
      @postal_codes = []
      @regions = []
      super
    end

    def country=(country)
      raise ArgumentError, 'country must be a FreightKit::Country' unless country.is_a?(Country)

      @country = country
    end
  end
end
