class BookName < ApplicationRecord
  belongs_to :translation
  belongs_to :book

  validates :name, presence: true
  validates :book_id, uniqueness: { scope: :translation_id }
end
