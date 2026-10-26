module FreightKit
  module Carriers
    class HerculesFreight < Carrier
      class << self
        def contacts
          [
            Contact.new(
              department: 'Customer Service - Los Angeles, CA',
              id: '8dae7040-c012-4d0f-a163-1b3623c42a44',
              phone: '+13232636100'
            )
          ]
        end

        def id = '2d5079bb-f42d-4bf5-9e2c-90df117de3c0'
        def name = 'Hercules Freight'
      end
    end
  end
end
