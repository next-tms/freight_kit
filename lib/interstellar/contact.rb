# frozen_string_literal: true

module FreightKit
  # Contact is the abstract base class for all contacts.
  #
  # @!attribute company_name [String] Company name.
  # @!attribute department_name [String] Department name (like "Shipping Dept").
  # @!attribute email [String] Email.
  # @!attribute fax [String] E164 formatted fax number.
  # @!attribute name [String] Name of person.
  # @!attribute phone [String] E164 formatted phone number.
  class Contact < Model
    attr_accessor :company_name, :department, :email, :fax, :name, :phone

    alias_method :company, :company_name
  end
end
