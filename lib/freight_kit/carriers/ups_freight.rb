module FreightKit
  module Carriers
    class UPSFreight < Carrier
      class << self
        def id = '307bb891-7b76-40a5-ac47-c3e5aa19eb88'
        def name = 'UPS Freight'
        def scac = 'UPGF'
        def website_url = 'https://www.tforcefreight.com'
      end
    end
  end
end
