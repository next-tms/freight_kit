module FreightKit
  module Carriers
    class JFJTransportation < Platforms::NextTMS
      class << self
        def consider_bol_and_pod_documents_same? = true
        def id = '115d5e86-2127-4072-b7b9-e0ef9e32b770'
        def name = 'JFJ Transportation'
      end

      API = Platforms::NextTMS::API.deep_merge(domain: 'app.jfjtransport.com').freeze
    end
  end
end
