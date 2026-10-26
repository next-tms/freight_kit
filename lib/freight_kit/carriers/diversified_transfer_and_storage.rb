module FreightKit
  module Carriers
    class DiversifiedTransferAndStorage < Carrier
      class << self
        def contacts
          [Contact.new(department: 'Main', id: 'e8155495-6837-4a8c-af89-e7c3399c0784', phone: '+14068963431')]
        end

        def headquarters
          Address.new(
            city: 'Billings',
            country: Countries.find_by(iso31661_alpha2: 'US'),
            id: 'fc2eebcc-8a53-4051-ad09-27eab0aefd5a',
            postal_code: '59101-3200',
            region_abbreviation: 'MT',
            street: '1640 Monad Rd'
          )
        end

        def id = '86c4d1a7-1a37-4dbb-a8d1-2fe158c43445'
        def legal_name = 'Diversified Transfer & Storage Inc'
        def name = 'Diversified Transfer & Storage'
        def us_dot_number = 357_293
        def us_mc_number = 215_020
        def website_url = 'https://www.dtsb.com'
      end
    end
  end
end
