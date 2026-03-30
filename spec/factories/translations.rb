FactoryBot.define do
  factory :translation do
    identifier { "eng-web" }
    name { "World English Bible" }
    language { "eng" }
    note { "Public Domain" }
  end
end
