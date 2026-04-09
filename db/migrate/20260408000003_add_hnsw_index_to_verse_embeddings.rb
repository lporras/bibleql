class AddHnswIndexToVerseEmbeddings < ActiveRecord::Migration[8.1]
  def change
    add_index :verses, :embedding,
              using: :hnsw,
              opclass: :vector_cosine_ops,
              name: "index_verses_on_embedding"
  end
end
