class AddNormalizedEmailToApiKeyRequests < ActiveRecord::Migration[8.1]
  # Backs the one-request-per-inbox-per-day limit (ApiKeyRequest::REQUEST_COOLDOWN). Existing rows
  # stay NULL: the limit only looks back 24 hours, and the form is paused while this ships.
  def change
    add_column :api_key_requests, :normalized_email, :string
    add_index :api_key_requests, [ :normalized_email, :created_at ]
  end
end
