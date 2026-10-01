class CreateOfflinePackages < ActiveRecord::Migration[8.1]
  def change
    create_table :offline_packages do |t|
      t.references :translation, null: false, foreign_key: true
      t.integer :schema_version, null: false
      t.string :storage_key, null: false
      t.string :url, null: false
      t.string :sha256, null: false
      t.bigint :size_bytes, null: false
      t.bigint :uncompressed_size_bytes, null: false
      t.string :source_digest, null: false
      t.integer :verse_count, null: false
      t.timestamps
    end
    add_index :offline_packages, [ :translation_id, :schema_version ], unique: true
  end
end
