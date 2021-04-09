# frozen_string_literal: true

module HyperCarrier
  module Carriers
    extend self

    attr_reader :registered
    @registered = []

    def register(class_name, autoload_require)
      HyperCarrier.autoload(class_name, autoload_require)
      self.registered << class_name
    end

    def all
      HyperCarrier::Carriers.registered.map { |name| HyperShipping.const_get(name) }
    end

    def find(name)
      all.find { |c| c.name.downcase == name.to_s.downcase } or raise NameError, "unknown carrier #{name}"
    end
  end
end

# ReactiveFreight carriers
HyperCarrier::Carriers.register :BenchmarkCarrier, 'hyper_carrier/carriers/benchmark_carrier'
HyperCarrier::Carriers.register :BogusCarrier, 'hyper_carrier/carriers/bogus_carrier'
HyperCarrier::Carriers.register :UPS, 'hyper_carrier/carriers/ups'
HyperCarrier::Carriers.register :USPS, 'hyper_carrier/carriers/usps'
HyperCarrier::Carriers.register :USPSReturns, 'hyper_carrier/carriers/usps_returns'
HyperCarrier::Carriers.register :FedEx, 'hyper_carrier/carriers/fedex'
HyperCarrier::Carriers.register :Shipwire, 'hyper_carrier/carriers/shipwire'
HyperCarrier::Carriers.register :Kunaki, 'hyper_carrier/carriers/kunaki'
HyperCarrier::Carriers.register :CanadaPost, 'hyper_carrier/carriers/canada_post'
HyperCarrier::Carriers.register :NewZealandPost, 'hyper_carrier/carriers/new_zealand_post'
HyperCarrier::Carriers.register :CanadaPostPWS, 'hyper_carrier/carriers/canada_post_pws'
HyperCarrier::Carriers.register :Stamps, 'hyper_carrier/carriers/stamps'
HyperCarrier::Carriers.register :AustraliaPost, 'hyper_carrier/carriers/australia_post'

# ReactiveFreight carriers
HyperCarrier::Carriers.register :BTVP, 'hyper_carrier/carriers/btvp'
HyperCarrier::Carriers.register :DPHE, 'hyper_carrier/carriers/dphe'
HyperCarrier::Carriers.register :DRRQ, 'hyper_carrier/carriers/drrq'
HyperCarrier::Carriers.register :FWDA, 'hyper_carrier/carriers/fwda'
HyperCarrier::Carriers.register :PENS, 'hyper_carrier/carriers/pens'
HyperCarrier::Carriers.register :RDFS, 'hyper_carrier/carriers/rdfs'
HyperCarrier::Carriers.register :SAIA, 'hyper_carrier/carriers/saia'
HyperCarrier::Carriers.register :SEFL, 'hyper_carrier/carriers/sefl'
HyperCarrier::Carriers.register :WRDS, 'hyper_carrier/carriers/wrds'

# ReactiveFreight platforms
HyperCarrier::Carriers.register :CLNI, 'hyper_carrier/carriers/clni'
HyperCarrier::Carriers.register :CTBV, 'hyper_carrier/carriers/ctbv'
HyperCarrier::Carriers.register :JFJTransportation, 'hyper_carrier/carriers/jfj_transportation'
HyperCarrier::Carriers.register :FCSY, 'hyper_carrier/carriers/fcsy'
HyperCarrier::Carriers.register :TOTL, 'hyper_carrier/carriers/totl'