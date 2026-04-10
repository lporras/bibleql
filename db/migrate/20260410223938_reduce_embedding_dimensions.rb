class ReduceEmbeddingDimensions < ActiveRecord::Migration[8.1]
  def up
    remove_index :verses, name: "index_verses_on_embedding"
    remove_column :verses, :embedding
    add_column :verses, :embedding, :vector, limit: 256
    add_index :verses, :embedding,
              using: :hnsw,
              opclass: :vector_cosine_ops,
              name: "index_verses_on_embedding"
  end

  def down
    remove_index :verses, name: "index_verses_on_embedding"
    remove_column :verses, :embedding
    add_column :verses, :embedding, :vector, limit: 1536
    add_index :verses, :embedding,
              using: :hnsw,
              opclass: :vector_cosine_ops,
              name: "index_verses_on_embedding"
  end
end
