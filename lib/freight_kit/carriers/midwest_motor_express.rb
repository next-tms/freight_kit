module FreightKit
  module Carriers
    class MidwestMotorExpress < Carrier
      class << self
        def id = 'e936c33e-3d9b-47dc-ad8c-d8b8beb29cd7'
        def legal_name = 'Midwest Motor Express, Inc.'
        def name = 'Midwest Motor Express'
        def scac = 'MIDW'
        def us_dot_number = 35_207
        def us_mc_number = 2_153
      end
    end
  end
end
