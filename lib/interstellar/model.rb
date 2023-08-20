# frozen_string_literal: true

module Interstellar
  class Model
    include ActiveModel::AttributeAssignment
    include ActiveModel::Validations

    def initialize(attributes = {})
      assign_attributes(attributes)
    end

    def attributes
      instance_values.with_indifferent_access
    end
    alias_method :to_hash, :attributes
  end
end
