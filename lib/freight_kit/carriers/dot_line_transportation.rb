module FreightKit
  module Carriers
    class DotLineTransportation < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'a02688e6-943e-4068-b683-69c901842520', phone: '+14054225463')]
        end

        def headquarters
          Address.new(
            city: 'El Reno',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '29274780-cfa8-41aa-8d8d-71c037592033',
            postal_code: '73036',
            region_abbreviation: 'OK',
            street: '3601 Valley Park Dr'
          )
        end

        def id = '10509883-6332-446b-9c9b-1b6e494a4624'
        def legal_name = 'Cal-cleve Limited'
        def name = 'Dot-Line Transportation'
        def scac = 'DOLR'
        def us_dot_number = 205_915
        def us_mc_number = 151_374
      end
    end
  end
end
