FactoryBot.define do
  factory :offline_package do
    translation
    schema_version { 1 }
    sequence(:sha256) { |n| Digest::SHA256.hexdigest(n.to_s) }
    storage_key { "translations/#{translation.identifier}/v#{schema_version}/#{sha256}.sqlite.gz" }
    url { "https://downloads.example.com/#{storage_key}" }
    size_bytes { 1_234_567 }
    uncompressed_size_bytes { 4_567_890 }
    source_digest { "digest" }
    verse_count { 31_102 }
  end
end
