# frozen_string_literal: true

module Interstellar
  module Carriers
    extend self

    attr_reader :registered

    @registered = []

    def register(class_name, autoload_require)
      Interstellar.autoload(class_name, autoload_require)
      registered << class_name
    end

    def all
      Interstellar::Carriers.registered.map { |name| Interstellar.const_get(name) }
    end

    def find(name)
      all.find { |c| c.name.downcase == name.to_s.downcase } or raise NameError, "unknown carrier #{name}"
    end
  end
end
