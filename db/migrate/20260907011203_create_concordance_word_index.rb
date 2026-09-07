class CreateConcordanceWordIndex < ActiveRecord::Migration[8.1]
  def change
    create_table :concordance_word_index do |t|
      t.references :translation, null: false, foreign_key: true
      t.string  :lemma, null: false
      t.integer :verse_count, null: false
      t.integer :total_occurrences, null: false
      t.timestamps
    end

    add_index :concordance_word_index, [ :translation_id, :lemma ], unique: true,
      name: "index_concordance_word_index_on_translation_id_and_lemma"
    add_index :concordance_word_index, [ :translation_id, :lemma ],
      name: "index_concordance_word_index_on_lemma_pattern",
      opclass: { lemma: :text_pattern_ops }
  end
end
