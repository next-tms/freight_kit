module FreightKit
  module Carriers
    class DohrnTransferCompany < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: '07442f32-3c5f-43ac-839e-7484af8221ca', phone: '+13097940723')]
        end

        def headquarters
          Address.new(
            city: 'Rock Island',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: '8d0d1e23-6d6a-44cf-abbf-4961a4faba4f',
            postal_code: '61201',
            region_abbreviation: 'IL',
            street: '625 Third Ave'
          )
        end

        def id = '083b37d7-9cd7-4c39-8873-8e29d7f7cc9d'
        def legal_name = 'Dohrn Transfer Company LLC'
        def name = 'Dohrn Transfer'
        def scac = 'DHRN'
        def us_dot_number = 541_227
        def us_mc_number = 169_753
        def website_url = 'https://www.dohrn.com'
      end
    end
  end
end
