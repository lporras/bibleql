class AddEmbeddingToVerses < ActiveRecord::Migration[8.1]
  def change
    add_column :verses, :embedding, :vector, limit: 1536
  end
end
