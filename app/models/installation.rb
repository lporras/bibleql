# One installed copy of a BibleQL client app (e.g. bibleql-reader). Registers itself via the
# registerInstallation mutation and owns the installation-kind ApiKey it authenticates with.
class Installation < ApplicationRecord
  PLATFORMS = %w[macos windows linux ios android].freeze
  UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
  APP_VERSION_FORMAT = /\A[0-9A-Za-z.+\-]{1,32}\z/
  SEEN_WRITE_INTERVAL = 1.hour

  has_many :api_keys, dependent: :nullify

  validates :installation_id, presence: true, uniqueness: true, format: { with: UUID_FORMAT }
  validates :platform, inclusion: { in: PLATFORMS }
  validates :app_version, format: { with: APP_VERSION_FORMAT }

  scope :active, -> { where(revoked_at: nil) }

  def self.ransackable_attributes(auth_object = nil)
    %w[id installation_id platform app_version last_seen_at revoked_at created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[api_keys]
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    transaction do
      update!(revoked_at: Time.current)
      api_keys.active.find_each(&:revoke!)
    end
  end

  # Called on every authenticated request; writes at most once per SEEN_WRITE_INTERVAL
  # unless the client reports a new version.
  def touch_seen!(reported_version)
    version = reported_version.to_s.match?(APP_VERSION_FORMAT) ? reported_version : app_version
    return if last_seen_at&.after?(SEEN_WRITE_INTERVAL.ago) && version == app_version

    update_columns(last_seen_at: Time.current, app_version: version)
  end
end
