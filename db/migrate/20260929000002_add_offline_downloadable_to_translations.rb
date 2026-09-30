# Licensing gate for offline packages: nothing is exported unless explicitly allowed.
class AddOfflineDownloadableToTranslations < ActiveRecord::Migration[8.1]
  def change
    add_column :translations, :offline_downloadable, :boolean, null: false, default: false
  end
end
