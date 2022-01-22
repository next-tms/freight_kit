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

Interstellar::Carriers.register :BTVP, 'interstellar-nexts/carriers/btvp'
Interstellar::Carriers.register :CLNI, 'interstellar-nexts/carriers/clni'
Interstellar::Carriers.register :DPHE, 'interstellar-nexts/carriers/dphe'
Interstellar::Carriers.register :DRRQ, 'interstellar-nexts/carriers/drrq'
Interstellar::Carriers.register :FWDA, 'interstellar-nexts/carriers/fwda'
Interstellar::Carriers.register :PENS, 'interstellar-nexts/carriers/pens'
Interstellar::Carriers.register :RDFS, 'interstellar-nexts/carriers/rdfs'
Interstellar::Carriers.register :SAIA, 'interstellar-nexts/carriers/saia'
Interstellar::Carriers.register :SEFL, 'interstellar-nexts/carriers/sefl'
Interstellar::Carriers.register :WRDS, 'interstellar-nexts/carriers/wrds'

# Based on Platform
Interstellar::Carriers.register :CTBV, 'interstellar-nexts/carriers/ctbv'
Interstellar::Carriers.register :JFJTransportation, 'interstellar-nexts/carriers/jfj_transportation'
Interstellar::Carriers.register :FCSY, 'interstellar-nexts/carriers/fcsy'
Interstellar::Carriers.register :TOTL, 'interstellar-nexts/carriers/totl'
