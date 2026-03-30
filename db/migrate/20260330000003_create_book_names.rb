class CreateBookNames < ActiveRecord::Migration[8.1]
  def change
    create_table :book_names do |t|
      t.references :translation, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :book_names, [ :translation_id, :book_id ], unique: true
    add_index :book_names, [ :translation_id, :name ]
  end
end
