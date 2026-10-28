FactoryBot.define do
  factory :installation do
    installation_id { SecureRandom.uuid }
    platform { "macos" }
    app_version { "1.0.0" }
  end
end
