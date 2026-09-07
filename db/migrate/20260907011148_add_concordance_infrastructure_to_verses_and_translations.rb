class AddConcordanceInfrastructureToVersesAndTranslations < ActiveRecord::Migration[8.1]
  def change
    add_column :verses, :text_search, :tsvector
    add_index  :verses, :text_search, using: :gin, name: "index_verses_on_text_search"

    add_column :translations, :text_search_config, :string, null: false, default: "simple"
    add_column :translations, :has_stemming, :boolean, null: false, default: false
    add_column :translations, :concordance_indexed_at, :datetime
  end
end
