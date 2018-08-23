module ReactiveShipping
  module Carriers
    extend self

    attr_reader :registered
    @registered = []

    def register(class_name, autoload_require)
      ReactiveShipping.autoload(class_name, autoload_require)
      self.registered << class_name
    end

    def all
      ReactiveShipping::Carriers.registered.map { |name| ReactiveShipping.const_get(name) }
    end

    def find(name)
      all.find { |c| c.name.downcase == name.to_s.downcase } or raise NameError, "unknown carrier #{name}"
    end
  end
end

ReactiveShipping::Carriers.register :BenchmarkCarrier, 'reactive_shipping/carriers/benchmark_carrier'
ReactiveShipping::Carriers.register :BogusCarrier,     'reactive_shipping/carriers/bogus_carrier'
ReactiveShipping::Carriers.register :UPS,              'reactive_shipping/carriers/ups'
ReactiveShipping::Carriers.register :USPS,             'reactive_shipping/carriers/usps'
ReactiveShipping::Carriers.register :USPSReturns,      'reactive_shipping/carriers/usps_returns'
ReactiveShipping::Carriers.register :FedEx,            'reactive_shipping/carriers/fedex'
ReactiveShipping::Carriers.register :Shipwire,         'reactive_shipping/carriers/shipwire'
ReactiveShipping::Carriers.register :Kunaki,           'reactive_shipping/carriers/kunaki'
ReactiveShipping::Carriers.register :CanadaPost,       'reactive_shipping/carriers/canada_post'
ReactiveShipping::Carriers.register :NewZealandPost,   'reactive_shipping/carriers/new_zealand_post'
ReactiveShipping::Carriers.register :CanadaPostPWS,    'reactive_shipping/carriers/canada_post_pws'
ReactiveShipping::Carriers.register :Stamps,           'reactive_shipping/carriers/stamps'
ReactiveShipping::Carriers.register :AustraliaPost,    'reactive_shipping/carriers/australia_post'
