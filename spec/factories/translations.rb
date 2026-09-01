FactoryBot.define do
  factory :translation do
    identifier { "eng-web" }
    name { "World English Bible" }
    language { "eng" }
    abbrev { "WEB" }
    language_name { "English" }
    note { "Public Domain" }
  end
end
