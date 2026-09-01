class AddMetadataToTranslations < ActiveRecord::Migration[8.1]
  def change
    add_column :translations, :abbrev, :string
    add_column :translations, :language_name, :string
  end
end
