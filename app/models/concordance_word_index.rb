class ConcordanceWordIndex < ApplicationRecord
  self.table_name = "concordance_word_index"

  belongs_to :translation
end
