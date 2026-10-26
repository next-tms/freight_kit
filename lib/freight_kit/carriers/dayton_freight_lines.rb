module FreightKit
  module Carriers
    class DaytonFreightLines < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'cb9c576e-e525-4254-90e0-190057a9d5eb', phone: '+19372644060')]
        end

        def headquarters
          Address.new(
            city: 'Dayton',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '619636dd-3364-462b-a71c-a243f37b430a',
            postal_code: '45414',
            region_abbreviation: 'OH',
            street: '6450 Poe Ave Suite 311'
          )
        end

        def id = '5b843d67-3fb7-4758-8f57-67f499f1d084'
        def legal_name = 'Dayton Freight Lines Inc'
        def name = 'Dayton Freight Lines'
        def scac = 'DAFG'
        def us_dot_number = 273_301
        def us_mc_number = 189_528
        def website_url = 'https://daytonfreight.com'
      end
    end
  end
end
