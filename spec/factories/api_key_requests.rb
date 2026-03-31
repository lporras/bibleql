FactoryBot.define do
  factory :api_key_request do
    name { "John Doe" }
    sequence(:email) { |n| "requester#{n}@example.com" }
    description { "Building a Bible study app" }
    environment { "test" }
    status { "pending" }
  end
end
