class ApiKeyRequest < ApplicationRecord
  # One request per inbox in this window, whatever the status, so the form can't be used to
  # flood someone's inbox (the approval email goes to whatever address is typed in).
  REQUEST_COOLDOWN = 24.hours
  GMAIL_DOMAINS = %w[gmail.com googlemail.com].freeze

  belongs_to :api_key, optional: true

  before_validation { self.normalized_email = self.class.normalize_email(email) }

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :description, presence: true
  validates :environment, presence: true, inclusion: { in: %w[live test] }
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }
  validate :no_duplicate_pending_request, on: :create
  validate :no_recent_request_for_inbox, on: :create

  def self.ransackable_attributes(auth_object = nil)
    %w[id name email environment status created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[api_key]
  end

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }

  # Collapses the spellings that reach the same inbox: case, "+tag" suffixes, and dots in Gmail
  # local parts. Only used for the rate limit; the key is still sent to the address as typed.
  def self.normalize_email(email)
    local, domain = email.to_s.strip.downcase.split("@", 2)
    return nil if local.blank? || domain.blank?

    local = local.split("+", 2).first
    local = local.delete(".") if GMAIL_DOMAINS.include?(domain)
    "#{local}@#{domain}"
  end

  def approve!
    transaction do
      api_key = ApiKey.create!(name: name, email: email, environment: environment)
      update!(status: "approved", api_key: api_key)
      api_key
    end
  end

  def reject!(reason = nil)
    update!(status: "rejected", rejection_reason: reason)
  end

  private

  def no_duplicate_pending_request
    if ApiKeyRequest.pending.exists?(email: email, environment: environment)
      errors.add(:email, "already has a pending request for this environment")
    end
  end

  def no_recent_request_for_inbox
    return if normalized_email.blank?

    if ApiKeyRequest.where(normalized_email: normalized_email, created_at: REQUEST_COOLDOWN.ago..).exists?
      errors.add(:email, "already requested a key recently. Please try again in 24 hours")
    end
  end
end
