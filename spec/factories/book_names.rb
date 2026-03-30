FactoryBot.define do
  factory :book_name do
    association :translation
    association :book
    name { "Genesis" }
  end
end
