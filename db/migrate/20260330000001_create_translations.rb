class CreateTranslations < ActiveRecord::Migration[8.1]
  def change
    create_table :translations do |t|
      t.string :identifier, null: false
      t.string :name, null: false
      t.string :language, null: false
      t.text :note

      t.timestamps
    end

    add_index :translations, :identifier, unique: true
    add_index :translations, :language
  end
end
