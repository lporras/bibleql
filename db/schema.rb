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

ActiveRecord::Schema[8.1].define(version: 2026_09_29_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

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

  create_table "concordance_word_index", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "lemma", null: false
    t.integer "total_occurrences", null: false
    t.bigint "translation_id", null: false
    t.datetime "updated_at", null: false
    t.integer "verse_count", null: false
    t.index ["translation_id", "lemma"], name: "index_concordance_word_index_on_lemma_pattern", opclass: { lemma: :text_pattern_ops }
    t.index ["translation_id", "lemma"], name: "index_concordance_word_index_on_translation_id_and_lemma", unique: true
    t.index ["translation_id"], name: "index_concordance_word_index_on_translation_id"
  end

  create_table "offline_packages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "schema_version", null: false
    t.string "sha256", null: false
    t.bigint "size_bytes", null: false
    t.string "source_digest", null: false
    t.string "storage_key", null: false
    t.bigint "translation_id", null: false
    t.bigint "uncompressed_size_bytes", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.integer "verse_count", null: false
    t.index ["translation_id", "schema_version"], name: "index_offline_packages_on_translation_id_and_schema_version", unique: true
    t.index ["translation_id"], name: "index_offline_packages_on_translation_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "translations", force: :cascade do |t|
    t.string "abbrev"
    t.datetime "concordance_indexed_at"
    t.datetime "created_at", null: false
    t.boolean "has_stemming", default: false, null: false
    t.string "identifier", null: false
    t.string "language", null: false
    t.string "language_name"
    t.string "name", null: false
    t.text "note"
    t.boolean "offline_downloadable", default: false, null: false
    t.string "text_search_config", default: "simple", null: false
    t.datetime "updated_at", null: false
    t.index ["identifier"], name: "index_translations_on_identifier", unique: true
    t.index ["language"], name: "index_translations_on_language"
  end

  create_table "verses", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.integer "chapter", null: false
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 256
    t.text "text", null: false
    t.tsvector "text_search"
    t.bigint "translation_id", null: false
    t.datetime "updated_at", null: false
    t.integer "verse_number", null: false
    t.index ["book_id"], name: "index_verses_on_book_id"
    t.index ["embedding"], name: "index_verses_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["text_search"], name: "index_verses_on_text_search", using: :gin
    t.index ["translation_id", "book_id", "chapter", "verse_number"], name: "index_verses_uniqueness", unique: true
    t.index ["translation_id", "book_id", "chapter"], name: "index_verses_on_translation_book_chapter"
    t.index ["translation_id"], name: "index_verses_on_translation_id"
  end

  add_foreign_key "api_key_requests", "api_keys"
  add_foreign_key "book_names", "books"
  add_foreign_key "book_names", "translations"
  add_foreign_key "concordance_word_index", "translations"
  add_foreign_key "offline_packages", "translations"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "verses", "books"
  add_foreign_key "verses", "translations"
end
