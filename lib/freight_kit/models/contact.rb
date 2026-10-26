module FreightKit
  # Contact is the abstract base class for all contacts.
  #
  # @!attribute company_name [String] Company name.
  # @!attribute department_name [String] Department name (like "Shipping Dept").
  # @!attribute email [String] Email.
  # @!attribute fax [String] E164 formatted fax number.
  # @!attribute id [String, nil] Permanent UUID of a carrier's contact. Applications store it, so never change it.
  # @!attribute name [String] Name of person.
  # @!attribute phone [String] E164 formatted phone number.
  class Contact < Model
    attr_accessor :company_name, :department, :email, :fax, :id, :name, :phone

    alias company company_name
  end
end
