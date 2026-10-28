class CreateInstallations < ActiveRecord::Migration[8.1]
  def change
    create_table :installations do |t|
      t.uuid :installation_id, null: false
      t.string :platform, null: false
      t.string :app_version, null: false
      t.datetime :last_seen_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :installations, :installation_id, unique: true

    change_table :api_keys, bulk: true do |t|
      t.string :kind, null: false, default: "developer"
      t.references :installation, foreign_key: true, null: true
      t.boolean :deprecated, null: false, default: false
    end
    add_index :api_keys, :kind
    change_column_null :api_keys, :email, true
  end
end
