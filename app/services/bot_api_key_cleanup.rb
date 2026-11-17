# One-off cleanup after the 2026 spam runs on the API key request form
# (rake api_keys:purge_bots). Deletes:
#
# - every rejected ApiKeyRequest (nearly all are bot submissions that failed on the email quota;
#   a rejected request never owns a key, since a failed auto-approve rolls the key back)
# - bot requests and the developer keys they created, recognized by what they submitted:
#   * casino spam in the name field (Nov 2026): a long message with a link
#   * a contact-form bot (since Sep 2026): a fixed SEO phrase as the description
#
# Real requests have a person's name and a sentence about their project, so neither pattern
# matches them. Bot keys that were actually used are still deleted, and returned as `used_keys`.
class BotApiKeyCleanup
  SPAM_NAME_MIN_LENGTH = 80
  SPAM_NAME_PATTERN = 'https?://|www\.'
  SPAM_DESCRIPTION_PREFIX = "I would like more information. Please contact me by email"

  Result = Data.define(:rejected_requests, :bot_requests, :bot_keys, :used_keys)

  def bot_requests
    ApiKeyRequest.where(
      "length(name) > :length OR name ~* :pattern OR description LIKE :prefix",
      length: SPAM_NAME_MIN_LENGTH, pattern: SPAM_NAME_PATTERN,
      prefix: "#{ApiKeyRequest.sanitize_sql_like(SPAM_DESCRIPTION_PREFIX)}%"
    )
  end

  # Rejected requests not already counted as bot requests, so the numbers don't overlap.
  def rejected_requests
    ApiKeyRequest.rejected.where.not(id: bot_requests.select(:id))
  end

  def bot_keys
    ApiKey.developer_keys.where(id: bot_requests.where.not(api_key_id: nil).select(:api_key_id))
  end

  def used_keys
    bot_keys.where("requests_count > 0").order(requests_count: :desc)
  end

  def preview
    Result.new(rejected_requests: rejected_requests.count, bot_requests: bot_requests.count,
               bot_keys: bot_keys.count, used_keys: used_keys.to_a)
  end

  # Requests go first: api_key_requests.api_key_id is a foreign key to api_keys.
  def call
    ApiKeyRequest.transaction do
      used = used_keys.to_a
      key_ids = bot_keys.pluck(:id)
      deleted_rejected = rejected_requests.delete_all
      deleted_bot_requests = bot_requests.delete_all
      # Any other request pointing at these keys (e.g. a later re-request) would block the delete.
      ApiKeyRequest.where(api_key_id: key_ids).update_all(api_key_id: nil)
      deleted_keys = ApiKey.where(id: key_ids).delete_all

      Result.new(rejected_requests: deleted_rejected, bot_requests: deleted_bot_requests,
                 bot_keys: deleted_keys, used_keys: used)
    end
  end
end
