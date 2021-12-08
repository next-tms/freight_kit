# frozen_string_literal: true

module Interstellar
  module Carriers
    extend self

    attr_reader :registered
    @registered = []

    def register(class_name, autoload_require)
      Interstellar.autoload(class_name, autoload_require)
      self.registered << class_name
    end

    def all
      Interstellar::Carriers.registered.map { |name| Interstellar.const_get(name) }
    end

    def find(name)
      all.find { |c| c.name.downcase == name.to_s.downcase } or raise NameError, "unknown carrier #{name}"
    end
  end
end

Interstellar::Carriers.register :BTVP, 'interstellar-next_carriers/carriers/btvp'
Interstellar::Carriers.register :DPHE, 'interstellar-next_carriers/carriers/dphe'
Interstellar::Carriers.register :DRRQ, 'interstellar-next_carriers/carriers/drrq'
Interstellar::Carriers.register :FWDA, 'interstellar-next_carriers/carriers/fwda'
Interstellar::Carriers.register :PENS, 'interstellar-next_carriers/carriers/pens'
Interstellar::Carriers.register :RDFS, 'interstellar-next_carriers/carriers/rdfs'
Interstellar::Carriers.register :SAIA, 'interstellar-next_carriers/carriers/saia'
Interstellar::Carriers.register :SEFL, 'interstellar-next_carriers/carriers/sefl'
Interstellar::Carriers.register :WRDS, 'interstellar-next_carriers/carriers/wrds'

# Based on Platform
Interstellar::Carriers.register :CTBV, 'interstellar-next_carriers/carriers/ctbv'
Interstellar::Carriers.register :JFJTransportation, 'interstellar-next_carriers/carriers/jfj_transportation'
Interstellar::Carriers.register :FCSY, 'interstellar-next_carriers/carriers/fcsy'
Interstellar::Carriers.register :TOTL, 'interstellar-next_carriers/carriers/totl'
