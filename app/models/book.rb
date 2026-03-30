class Book < ApplicationRecord
  has_many :verses, dependent: :destroy
  has_many :book_names, dependent: :destroy

  validates :book_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :testament, presence: true, inclusion: { in: %w[OT NT] }
  validates :position, presence: true, uniqueness: true
end
