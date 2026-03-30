class Verse < ApplicationRecord
  belongs_to :translation
  belongs_to :book

  validates :chapter, presence: true
  validates :verse_number, presence: true, uniqueness: { scope: [:translation_id, :book_id, :chapter] }
  validates :text, presence: true
end
