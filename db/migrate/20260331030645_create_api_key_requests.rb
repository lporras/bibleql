class CreateApiKeyRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :api_key_requests do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.text :description, null: false
      t.string :environment, null: false, default: "test"
      t.string :status, null: false, default: "pending"
      t.text :rejection_reason
      t.references :api_key, null: true, foreign_key: true

      t.timestamps
    end

    add_index :api_key_requests, [ :email, :environment, :status ]
  end
end
