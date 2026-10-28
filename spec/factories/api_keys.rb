FactoryBot.define do
  factory :api_key do
    name { "Test App" }
    sequence(:email) { |n| "testapp#{n}@example.com" }
    environment { "test" }

    trait :installation do
      kind { "installation" }
      name { "macos installation" }
      email { nil }
      installation
    end

    trait :deprecated do
      deprecated { true }
    end
  end
end
