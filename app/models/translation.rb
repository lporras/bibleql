class Translation < ApplicationRecord
  has_many :verses, dependent: :destroy
  has_many :book_names, dependent: :destroy
  has_many :offline_packages, dependent: :destroy

  validates :identifier, presence: true, uniqueness: true
  validates :name, presence: true
  validates :language, presence: true

  scope :offline_downloadable, -> { where(offline_downloadable: true) }

  # ActiveAdmin filters (app/admin/offline_packages.rb)
  def self.ransackable_attributes(_auth_object = nil)
    %w[identifier language name offline_downloadable]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
