# frozen_string_literal: true

module Interstellar
  class Model
    include ActiveModel::AttributeAssignment

    def attributes
      instance_values.with_indifferent_access
    end
    alias to_hash attributes
  end
end
