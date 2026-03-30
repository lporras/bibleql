class CreateVerses < ActiveRecord::Migration[8.1]
  def change
    create_table :verses do |t|
      t.references :translation, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.integer :chapter, null: false
      t.integer :verse_number, null: false
      t.text :text, null: false

      t.timestamps
    end

    add_index :verses, [:translation_id, :book_id, :chapter, :verse_number],
              unique: true, name: "index_verses_uniqueness"
    add_index :verses, [:translation_id, :book_id, :chapter],
              name: "index_verses_on_translation_book_chapter"
  end
end
