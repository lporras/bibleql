# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_31_033608) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type"
    t.text "body"
    t.datetime "created_at", null: false
    t.string "namespace"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "api_key_requests", force: :cascade do |t|
    t.bigint "api_key_id"
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "email", null: false
    t.string "environment", default: "test", null: false
    t.string "name", null: false
    t.text "rejection_reason"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key_id"], name: "index_api_key_requests_on_api_key_id"
    t.index ["email", "environment", "status"], name: "index_api_key_requests_on_email_and_environment_and_status"
  end

  create_table "api_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "daily_limit", default: 1000, null: false
    t.string "email", null: false
    t.string "environment", default: "test", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.integer "requests_count", default: 0, null: false
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.string "token_prefix", limit: 12, null: false
    t.datetime "updated_at", null: false
    t.index ["email", "environment"], name: "index_api_keys_on_email_and_environment_active", unique: true, where: "(revoked_at IS NULL)"
    t.index ["revoked_at"], name: "index_api_keys_on_revoked_at"
    t.index ["token_digest"], name: "index_api_keys_on_token_digest", unique: true
    t.index ["token_prefix"], name: "index_api_keys_on_token_prefix"
  end

  create_table "book_names", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "translation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_book_names_on_book_id"
    t.index ["translation_id", "book_id"], name: "index_book_names_on_translation_id_and_book_id", unique: true
    t.index ["translation_id", "name"], name: "index_book_names_on_translation_id_and_name"
    t.index ["translation_id"], name: "index_book_names_on_translation_id"
  end

  create_table "books", force: :cascade do |t|
    t.string "book_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.string "testament", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_books_on_book_id", unique: true
    t.index ["position"], name: "index_books_on_position", unique: true
  end

  create_table "translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "identifier", null: false
    t.string "language", null: false
    t.string "name", null: false
    t.text "note"
    t.datetime "updated_at", null: false
    t.index ["identifier"], name: "index_translations_on_identifier", unique: true
    t.index ["language"], name: "index_translations_on_language"
  end

  create_table "verses", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.integer "chapter", null: false
    t.datetime "created_at", null: false
    t.text "text", null: false
    t.bigint "translation_id", null: false
    t.datetime "updated_at", null: false
    t.integer "verse_number", null: false
    t.index ["book_id"], name: "index_verses_on_book_id"
    t.index ["translation_id", "book_id", "chapter", "verse_number"], name: "index_verses_uniqueness", unique: true
    t.index ["translation_id", "book_id", "chapter"], name: "index_verses_on_translation_book_chapter"
    t.index ["translation_id"], name: "index_verses_on_translation_id"
  end

  add_foreign_key "api_key_requests", "api_keys"
  add_foreign_key "book_names", "books"
  add_foreign_key "book_names", "translations"
  add_foreign_key "verses", "books"
  add_foreign_key "verses", "translations"
end
