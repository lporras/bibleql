class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :book_id, null: false
      t.string :name, null: false
      t.string :testament, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :books, :book_id, unique: true
    add_index :books, :position, unique: true
  end
end
