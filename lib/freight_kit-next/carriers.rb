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

FreightKit::Carriers.register(:BTVP, 'freight_kit-next/carriers/btvp')
FreightKit::Carriers.register(:CCYQ, 'freight_kit-next/carriers/ccyq')
FreightKit::Carriers.register(:CLNI, 'freight_kit-next/carriers/clni')
FreightKit::Carriers.register(:CNWY, 'freight_kit-next/carriers/cnwy')
FreightKit::Carriers.register(:DPHE, 'freight_kit-next/carriers/dphe')
FreightKit::Carriers.register(:DRRQ, 'freight_kit-next/carriers/drrq')
FreightKit::Carriers.register(:FWDA, 'freight_kit-next/carriers/fwda')
FreightKit::Carriers.register(:MTVL, 'freight_kit-next/carriers/mtvl')
FreightKit::Carriers.register(:NUMT, 'freight_kit-next/carriers/numt')
FreightKit::Carriers.register(:OTCL, 'freight_kit-next/carriers/otcl')
FreightKit::Carriers.register(:PENS, 'freight_kit-next/carriers/pens')
FreightKit::Carriers.register(:RDFS, 'freight_kit-next/carriers/rdfs')
FreightKit::Carriers.register(:SAIA, 'freight_kit-next/carriers/saia')
FreightKit::Carriers.register(:SEFL, 'freight_kit-next/carriers/sefl')
FreightKit::Carriers.register(:TQYL, 'freight_kit-next/carriers/tqyl')
FreightKit::Carriers.register(:WRDS, 'freight_kit-next/carriers/wrds')

# Based on Platform
FreightKit::Carriers.register(:CTBV, 'freight_kit-next/carriers/ctbv')
FreightKit::Carriers.register(:DCHA, 'freight_kit-next/carriers/dcha')
FreightKit::Carriers.register(:JFJTransportation, 'freight_kit-next/carriers/jfj_transportation')
FreightKit::Carriers.register(:FCSY, 'freight_kit-next/carriers/fcsy')
FreightKit::Carriers.register(:TOTL, 'freight_kit-next/carriers/totl')
