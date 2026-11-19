module FreightKit
  module Carriers
    class ChampsFreightSolutions < Platforms::NextTMS
      class << self
        def consider_bol_and_pod_documents_same? = true
        def id = '850ea54e-1547-4ced-a20d-96dc85f47243'
        def name = 'Champs Freight Solutions'
      end

      API = Platforms::NextTMS::API.deep_merge(domain: 'champsfreightsolutions.com').freeze
    end
  end
end
