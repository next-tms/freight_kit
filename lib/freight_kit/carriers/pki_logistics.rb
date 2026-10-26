module FreightKit
  module Carriers
    class PKILogistics < Carrier
      class << self
        def acts_as_broker? = true
        def consider_bol_and_pod_documents_same? = true
        def id = '20488a7d-afc8-4e19-b093-c12e443f686d'
        def name = 'PKI Logistics'
      end
    end
  end
end
