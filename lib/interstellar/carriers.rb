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

# ReactiveFreight carriers
Interstellar::Carriers.register :BenchmarkCarrier, 'interstellar/carriers/benchmark_carrier'
Interstellar::Carriers.register :BogusCarrier, 'interstellar/carriers/bogus_carrier'
Interstellar::Carriers.register :UPS, 'interstellar/carriers/ups'
Interstellar::Carriers.register :USPS, 'interstellar/carriers/usps'
Interstellar::Carriers.register :USPSReturns, 'interstellar/carriers/usps_returns'
Interstellar::Carriers.register :FedEx, 'interstellar/carriers/fedex'
Interstellar::Carriers.register :Shipwire, 'interstellar/carriers/shipwire'
Interstellar::Carriers.register :Kunaki, 'interstellar/carriers/kunaki'
Interstellar::Carriers.register :CanadaPost, 'interstellar/carriers/canada_post'
Interstellar::Carriers.register :NewZealandPost, 'interstellar/carriers/new_zealand_post'
Interstellar::Carriers.register :CanadaPostPWS, 'interstellar/carriers/canada_post_pws'
Interstellar::Carriers.register :Stamps, 'interstellar/carriers/stamps'
Interstellar::Carriers.register :AustraliaPost, 'interstellar/carriers/australia_post'

# ReactiveFreight carriers
Interstellar::Carriers.register :BTVP, 'interstellar/carriers/btvp'
Interstellar::Carriers.register :DPHE, 'interstellar/carriers/dphe'
Interstellar::Carriers.register :DRRQ, 'interstellar/carriers/drrq'
Interstellar::Carriers.register :FWDA, 'interstellar/carriers/fwda'
Interstellar::Carriers.register :PENS, 'interstellar/carriers/pens'
Interstellar::Carriers.register :RDFS, 'interstellar/carriers/rdfs'
Interstellar::Carriers.register :SAIA, 'interstellar/carriers/saia'
Interstellar::Carriers.register :SEFL, 'interstellar/carriers/sefl'
Interstellar::Carriers.register :WRDS, 'interstellar/carriers/wrds'

# ReactiveFreight platforms
Interstellar::Carriers.register :CLNI, 'interstellar/carriers/clni'
Interstellar::Carriers.register :CTBV, 'interstellar/carriers/ctbv'
Interstellar::Carriers.register :JFJTransportation, 'interstellar/carriers/jfj_transportation'
Interstellar::Carriers.register :FCSY, 'interstellar/carriers/fcsy'
Interstellar::Carriers.register :TOTL, 'interstellar/carriers/totl'