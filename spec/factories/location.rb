# frozen_string_literal: true

FactoryBot.define do
  factory(:location, class: 'FreightKit::Location') do
    association :contact

    address1 { Faker::Address.street_address }
    city { Faker::Address.city }
    country { ActiveUtils::Country.find('US') }
    postal_code { Faker::Address.postcode }
    province { Faker::Address.state_abbr }

    initialize_with { new(attributes) }
  end
end
