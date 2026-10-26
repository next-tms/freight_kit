module FreightKit
  # Class representing a carrier's terminal.
  #
  # @!attribute address [FreightKit::Address] Address.
  # @!attribute id [String] Permanent UUID. Applications store it, so never change it.
  # @!attribute phone [String] E164 formatted phone number.
  class Terminal < Model
    attr_accessor :address, :id, :phone
  end
end
