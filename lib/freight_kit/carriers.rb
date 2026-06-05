# frozen_string_literal: true

module FreightKit
  module Carriers
    extend self

    attr_reader :registered

    @registered = []

    def register(class_name, autoload_require)
      FreightKit.autoload(class_name, autoload_require)
      registered << class_name
    end

    def all
      FreightKit::Carriers.registered.map { |name| FreightKit.const_get(name) }
    end

    def find(name)
      all.find { |c| c.name.downcase == name.to_s.downcase } or raise NameError, "unknown carrier #{name}"
    end
  end
end

FreightKit::Carriers.register(:ABFS, 'freight_kit/carriers/abfs')
FreightKit::Carriers.register(:BTVP, 'freight_kit/carriers/btvp')
FreightKit::Carriers.register(:CCYQ, 'freight_kit/carriers/ccyq')
FreightKit::Carriers.register(:CLNI, 'freight_kit/carriers/clni')
FreightKit::Carriers.register(:CNWY, 'freight_kit/carriers/cnwy')
FreightKit::Carriers.register(:DLDS, 'freight_kit/carriers/dlds')
FreightKit::Carriers.register(:DPHE, 'freight_kit/carriers/dphe')
FreightKit::Carriers.register(:DRRQ, 'freight_kit/carriers/drrq')
FreightKit::Carriers.register(:FWDA, 'freight_kit/carriers/fwda')
FreightKit::Carriers.register(:MTVL, 'freight_kit/carriers/mtvl')
FreightKit::Carriers.register(:NUMK, 'freight_kit/carriers/numk')
FreightKit::Carriers.register(:OTCL, 'freight_kit/carriers/otcl')
FreightKit::Carriers.register(:PENS, 'freight_kit/carriers/pens')
FreightKit::Carriers.register(:RDFS, 'freight_kit/carriers/rdfs')
FreightKit::Carriers.register(:SAIA, 'freight_kit/carriers/saia')
FreightKit::Carriers.register(:SEFL, 'freight_kit/carriers/sefl')
FreightKit::Carriers.register(:TQYL, 'freight_kit/carriers/tqyl')
FreightKit::Carriers.register(:WRDS, 'freight_kit/carriers/wrds')

# Based on Platform
FreightKit::Carriers.register(:CTBV, 'freight_kit/carriers/ctbv')
FreightKit::Carriers.register(:DCHA, 'freight_kit/carriers/dcha')
FreightKit::Carriers.register(:JFJTransportation, 'freight_kit/carriers/jfj_transportation')
FreightKit::Carriers.register(:FCSY, 'freight_kit/carriers/fcsy')
FreightKit::Carriers.register(:TOTL, 'freight_kit/carriers/totl')
