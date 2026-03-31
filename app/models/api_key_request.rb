class ApiKeyRequest < ApplicationRecord
  belongs_to :api_key, optional: true

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :description, presence: true
  validates :environment, presence: true, inclusion: { in: %w[live test] }
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }
  validate :no_duplicate_pending_request, on: :create

  def self.ransackable_attributes(auth_object = nil)
    %w[id name email environment status created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[api_key]
  end

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }

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
end
