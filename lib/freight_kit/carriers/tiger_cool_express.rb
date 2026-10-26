module FreightKit
  module Carriers
    class TigerCoolExpress < Carrier
      class << self
        def consider_bol_and_pod_documents_same? = true
        def id = 'd810cbab-4984-43ab-8f21-b2ec79a5f74c'
        def name = 'Tiger Cool Express'
      end
    end
  end
end
