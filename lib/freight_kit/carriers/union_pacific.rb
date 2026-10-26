module FreightKit
  module Carriers
    class UnionPacific < Carrier
      class << self
        def id = '1f00cbdc-df10-4dd2-8214-68867a4da8fa'
        def name = 'Union Pacific'
        def website_url = 'https://www.up.com'
      end
    end
  end
end
