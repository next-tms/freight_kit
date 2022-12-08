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

Interstellar::Carriers.register :BTVP, 'interstellar-next/carriers/btvp'
Interstellar::Carriers.register :CCYQ, 'interstellar-next/carriers/ccyq'
Interstellar::Carriers.register :CLNI, 'interstellar-next/carriers/clni'
Interstellar::Carriers.register :CNWY, 'interstellar-next/carriers/cnwy'
Interstellar::Carriers.register :DPHE, 'interstellar-next/carriers/dphe'
Interstellar::Carriers.register :DRRQ, 'interstellar-next/carriers/drrq'
Interstellar::Carriers.register :FWDA, 'interstellar-next/carriers/fwda'
Interstellar::Carriers.register :NUMT, 'interstellar-next/carriers/numt'
Interstellar::Carriers.register :OTCL, 'interstellar-next/carriers/otcl'
Interstellar::Carriers.register :PENS, 'interstellar-next/carriers/pens'
Interstellar::Carriers.register :RDFS, 'interstellar-next/carriers/rdfs'
Interstellar::Carriers.register :SAIA, 'interstellar-next/carriers/saia'
Interstellar::Carriers.register :SEFL, 'interstellar-next/carriers/sefl'
Interstellar::Carriers.register :WRDS, 'interstellar-next/carriers/wrds'

# Based on Platform
Interstellar::Carriers.register :CTBV, 'interstellar-next/carriers/ctbv'
Interstellar::Carriers.register :JFJTransportation, 'interstellar-next/carriers/jfj_transportation'
Interstellar::Carriers.register :FCSY, 'interstellar-next/carriers/fcsy'
Interstellar::Carriers.register :TOTL, 'interstellar-next/carriers/totl'
