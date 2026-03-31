class ApiKey < ApplicationRecord
  attr_accessor :token

  has_many :api_key_requests, dependent: :nullify

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { scope: :environment, conditions: -> { active } }
  validates :token_digest, presence: true, uniqueness: true
  validates :token_prefix, presence: true
  validates :environment, presence: true, inclusion: { in: %w[live test] }

  def self.ransackable_attributes(auth_object = nil)
    %w[id name email token_prefix environment requests_count last_used_at revoked_at daily_limit created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[api_key_requests]
  end

  scope :active, -> { where(revoked_at: nil) }
  scope :live, -> { where(environment: "live") }
  scope :test_env, -> { where(environment: "test") }

  before_validation :generate_token, on: :create

  def self.authenticate(plain_token)
    return nil if plain_token.blank?

    prefix = plain_token[0, 12]
    candidates = active.where(token_prefix: prefix)

    candidates.find do |candidate|
      BCrypt::Password.new(candidate.token_digest) == plain_token
    end
  end

  def self.expected_environment
    Rails.env.production? ? "live" : "test"
  end

  def regenerate!
    transaction do
      revoke!
      self.class.create!(name: name, email: email, environment: environment)
    end
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  def track_usage!
    update_columns(requests_count: requests_count + 1, last_used_at: Time.current)
  end

  private

  def generate_token
    self.token = "bql_#{environment}_#{SecureRandom.urlsafe_base64(32)}"
    self.token_digest = BCrypt::Password.create(token)
    self.token_prefix = token[0, 12]
  end
end
