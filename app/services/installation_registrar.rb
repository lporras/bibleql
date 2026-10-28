# Issues a fresh installation key for a client install (registerInstallation mutation).
#
# Re-registering the same installation_id revokes every key it held before and issues a new
# one: an existing token is never returned, because only its digest is stored.
class InstallationRegistrar
  class Revoked < StandardError; end

  def self.call(...)
    new(...).call
  end

  def initialize(installation_id:, platform:, app_version:)
    @installation_id = installation_id.to_s.downcase
    @platform = platform.to_s
    @app_version = app_version.to_s
  end

  # Returns the new ApiKey; its plaintext `token` is only available on this instance.
  # Raises ActiveRecord::RecordInvalid for bad input and Revoked for a banned installation.
  def call
    Installation.transaction do
      installation = find_or_create_installation
      installation.lock!
      raise Revoked, "This installation has been revoked." if installation.revoked?

      installation.update!(platform: @platform, app_version: @app_version, last_seen_at: Time.current)
      installation.api_keys.active.find_each(&:revoke!)
      installation.api_keys.create!(
        kind: "installation",
        name: "#{@platform} installation",
        environment: ApiKey.expected_environment
      )
    end
  end

  private

  def find_or_create_installation
    Installation.find_by(installation_id: @installation_id) ||
      # Savepoint, so a lost insert race doesn't abort the surrounding transaction.
      Installation.transaction(requires_new: true) do
        Installation.create!(installation_id: @installation_id, platform: @platform, app_version: @app_version)
      end
  rescue ActiveRecord::RecordNotUnique
    # A concurrent registration for the same id won the insert.
    Installation.find_by!(installation_id: @installation_id)
  rescue ActiveRecord::RecordInvalid => e
    # Same race, caught by the uniqueness validation before the database constraint.
    raise unless e.record.errors.of_kind?(:installation_id, :taken)

    Installation.find_by!(installation_id: @installation_id)
  end
end
