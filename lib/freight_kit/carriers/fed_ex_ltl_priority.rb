module FreightKit
  module Carriers
    class FedExLTLPriority < Carrier
      class << self
        def id = '35221b55-e3b1-45a9-b790-99cdb6a86fd1'
        def name = 'FedEx LTL Priority'
        def scac = 'FXFE'
      end
    end
  end
end
