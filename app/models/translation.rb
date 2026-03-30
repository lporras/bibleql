class Translation < ApplicationRecord
  has_many :verses, dependent: :destroy
  has_many :book_names, dependent: :destroy

  validates :identifier, presence: true, uniqueness: true
  validates :name, presence: true
  validates :language, presence: true
end
