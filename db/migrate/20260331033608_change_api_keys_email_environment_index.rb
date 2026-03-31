class ChangeApiKeysEmailEnvironmentIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :api_keys, [ :email, :environment ]
    add_index :api_keys, [ :email, :environment ], unique: true, where: "revoked_at IS NULL",
      name: "index_api_keys_on_email_and_environment_active"
  end
end
