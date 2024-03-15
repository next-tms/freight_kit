# frozen_string_literal: true

FactoryBot.define do
  factory(:contact, class: 'FreightKit::Contact') do
    company_name { Faker::Company.name }
    department { Faker::Company.department }
    email { Faker::Internet.email }
    fax { Faker::PhoneNumber.phone_number_with_country_code }
    name { "#{Faker::Name.first_name} #{Faker::Name.last_name}" }
    phone { Faker::PhoneNumber.phone_number_with_country_code }
    
    initialize_with { new(attributes) }
  end
end
