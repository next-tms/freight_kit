module FreightKit
  module Carriers
    class AberdeenExpressInc < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '7e1cc9f0-fa9f-45f4-b874-4369edf1e5d5', phone: '+15137723210')]
        end

        def headquarters
          Address.new(
            city: 'Sharonville',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'f9691559-d586-420f-8772-c1fd2ef6fb64',
            postal_code: '45241',
            region_abbreviation: 'OH',
            street: '2490-B Commerce Blvd'
          )
        end

        def id = '176e3b36-1769-4d3f-85d5-ed9ea0ccb70f'
        def legal_name = 'Aberdeen Express Inc'
        def name = 'Aberdeen Express'
        def scac = 'ABNE'
        def us_dot_number = 262_824
      end
    end
  end
end
