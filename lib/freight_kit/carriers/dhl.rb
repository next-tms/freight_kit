module FreightKit
  module Carriers
    class DHL < Carrier
      class << self
        def id = '617c592f-ec16-4ef5-b5bc-22be37888730'
        def name = 'DHL'
        def website_url = 'https://www.deutschepost.de'
      end
    end
  end
end
