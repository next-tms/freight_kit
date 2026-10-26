module FreightKit
  module Carriers
    class MavCanadianTransport < Carrier
      class << self
        def id = '1eba18c5-1554-44fd-a22e-8a767a02f5e1'
        def legal_name = 'Mav Canadian Transport LLC'
        def name = 'Mav Canadian Transport'
        def us_dot_number = 2_941_410
        def us_mc_number = 994_843
      end
    end
  end
end
