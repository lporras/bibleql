FactoryBot.define do
  factory :verse do
    association :translation
    association :book
    chapter { 1 }
    verse_number { 1 }
    text { "In the beginning God created the heavens and the earth." }
  end
end
