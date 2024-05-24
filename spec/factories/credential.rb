# frozen_string_literal: true

FactoryBot.define do
  factory(:credential, class: 'FreightKit::Credential') do
    factory(:api_credential) do
      type { :api }
      account { Faker::Number.number(digits: 9).to_s }
      username { Faker::Internet.username }
      password { Faker::Internet.password }

      initialize_with { new(attributes) }
    end
  end
end
