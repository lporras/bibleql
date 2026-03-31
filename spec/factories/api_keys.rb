FactoryBot.define do
  factory :api_key do
    name { "Test App" }
    sequence(:email) { |n| "testapp#{n}@example.com" }
    environment { "test" }
  end
end
