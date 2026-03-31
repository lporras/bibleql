class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, limit: 12, null: false
      t.string :environment, null: false, default: "test"
      t.integer :requests_count, null: false, default: 0
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.integer :daily_limit, null: false, default: 1000

      t.timestamps
    end

    add_index :api_keys, :token_digest, unique: true
    add_index :api_keys, :token_prefix
    add_index :api_keys, [ :email, :environment ], unique: true
    add_index :api_keys, :revoked_at
  end
end
