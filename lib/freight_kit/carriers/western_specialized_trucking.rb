module FreightKit
  module Carriers
    class WesternSpecializedTrucking < Carrier
      class << self
        def contacts
          [
            Contact.new(
              department: 'Customer Service',
              email: 'operations@truckwestern.com',
              id: '335e92c7-7946-4888-84fb-d7c30d3615b2',
              phone: '+15073453300'
            )
          ]
        end

        def id = '5aadc871-b9d4-4a43-9ef9-7ae3f03a2f7a'
        def name = 'Western Specialized Trucking'
        def website_url = 'https://www.truckwestern.com'
      end
    end
  end
end
