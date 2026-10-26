module FreightKit
  module Carriers
    class CustomGlobalLogistics < Carrier
      class << self
        def id = 'a1a410c9-0a21-41f6-8dfe-28aa43930b45'
        def legal_name = 'Custom Global Logistics, LLC'
        def name = 'Custom Global Logistics'
        def scac = 'CGLA'
        def us_dot_number = 2_227_976
        def us_mc_number = 410_857
      end
    end
  end
end
