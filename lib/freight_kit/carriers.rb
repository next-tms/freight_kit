# frozen_string_literal: true

module FreightKit
  module Carriers
    extend self

    attr_reader :registered

    @registered = []

    def register(class_name)
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

FreightKit::Carriers.register(:ABFS)
FreightKit::Carriers.register(:BTVP)
FreightKit::Carriers.register(:CCYQ)
FreightKit::Carriers.register(:CLNI)
FreightKit::Carriers.register(:CNWY)
FreightKit::Carriers.register(:DLDS)
FreightKit::Carriers.register(:DPHE)
FreightKit::Carriers.register(:DRRQ)
FreightKit::Carriers.register(:FWDA)
FreightKit::Carriers.register(:MTVL)
FreightKit::Carriers.register(:NUMK)
FreightKit::Carriers.register(:OTCL)
FreightKit::Carriers.register(:PENS)
FreightKit::Carriers.register(:RDFS)
FreightKit::Carriers.register(:SAIA)
FreightKit::Carriers.register(:SEFL)
FreightKit::Carriers.register(:TQYL)
FreightKit::Carriers.register(:WRDS)

# Based on Platform
FreightKit::Carriers.register(:CTBV)
FreightKit::Carriers.register(:DCHA)
FreightKit::Carriers.register(:JFJTransportation)
FreightKit::Carriers.register(:FCSY)
FreightKit::Carriers.register(:TOTL)
