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

ActiveRecord::Schema[8.1].define(version: 2026_09_07_110721) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "announcements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.datetime "published_at"
    t.date "starts_on"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["published_at"], name: "index_announcements_on_published_at"
    t.index ["user_id"], name: "index_announcements_on_user_id"
  end

  create_table "api_token_areas", force: :cascade do |t|
    t.bigint "api_token_id", null: false
    t.bigint "area_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token_id", "area_id"], name: "index_api_token_areas_on_api_token_id_and_area_id", unique: true
    t.index ["api_token_id"], name: "index_api_token_areas_on_api_token_id"
    t.index ["area_id"], name: "index_api_token_areas_on_area_id"
  end

  create_table "api_tokens", force: :cascade do |t|
    t.boolean "all_areas", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "areas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon"
    t.string "name", null: false
    t.bigint "parent_id"
    t.integer "position", default: 0, null: false
    t.boolean "public", default: false, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_areas_on_parent_id"
    t.index ["public"], name: "index_areas_on_public"
    t.index ["slug"], name: "index_areas_on_slug", unique: true
  end

  create_table "audits", force: :cascade do |t|
    t.string "action"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "auditable_id"
    t.string "auditable_type"
    t.text "audited_changes"
    t.string "comment"
    t.datetime "created_at"
    t.string "remote_address"
    t.string "request_uuid"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "chart_columns", force: :cascade do |t|
    t.bigint "chart_table_id", null: false
    t.datetime "created_at", null: false
    t.string "data_type"
    t.string "default_value"
    t.string "name", null: false
    t.boolean "nullable", default: true, null: false
    t.integer "position", default: 0, null: false
    t.boolean "primary_key", default: false, null: false
    t.boolean "unique", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["chart_table_id", "name"], name: "index_chart_columns_on_chart_table_id_and_name", unique: true
    t.index ["chart_table_id"], name: "index_chart_columns_on_chart_table_id"
  end

  create_table "chart_indices", force: :cascade do |t|
    t.bigint "chart_table_id", null: false
    t.string "columns", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "unique", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["chart_table_id"], name: "index_chart_indices_on_chart_table_id"
  end

  create_table "chart_relationships", force: :cascade do |t|
    t.bigint "chart_id", null: false
    t.datetime "created_at", null: false
    t.bigint "from_chart_column_id", null: false
    t.string "on_delete"
    t.string "on_update"
    t.bigint "to_chart_column_id", null: false
    t.datetime "updated_at", null: false
    t.index ["chart_id"], name: "index_chart_relationships_on_chart_id"
    t.index ["from_chart_column_id"], name: "index_chart_relationships_on_from_chart_column_id"
    t.index ["to_chart_column_id"], name: "index_chart_relationships_on_to_chart_column_id"
  end

  create_table "chart_tables", force: :cascade do |t|
    t.bigint "chart_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.index ["chart_id", "name"], name: "index_chart_tables_on_chart_id_and_name", unique: true
    t.index ["chart_id"], name: "index_chart_tables_on_chart_id"
  end

  create_table "charts", force: :cascade do |t|
    t.bigint "area_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon"
    t.integer "position", default: 0, null: false
    t.boolean "public", default: false, null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["area_id", "slug"], name: "index_charts_on_area_id_and_slug", unique: true
    t.index ["area_id"], name: "index_charts_on_area_id"
    t.index ["public"], name: "index_charts_on_public"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "pages", force: :cascade do |t|
    t.bigint "area_id", null: false
    t.datetime "created_at", null: false
    t.string "icon"
    t.integer "position", default: 0, null: false
    t.boolean "public", default: false, null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["area_id", "slug"], name: "index_pages_on_area_id_and_slug", unique: true
    t.index ["area_id"], name: "index_pages_on_area_id"
    t.index ["public"], name: "index_pages_on_public"
    t.index ["user_id"], name: "index_pages_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.boolean "public", default: false, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["public"], name: "index_projects_on_public"
    t.index ["slug"], name: "index_projects_on_slug", unique: true
  end

  create_table "roadmap_cards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "estimated_release_on"
    t.integer "position", default: 0, null: false
    t.bigint "roadmap_section_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["roadmap_section_id"], name: "index_roadmap_cards_on_roadmap_section_id"
  end

  create_table "roadmap_sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_roadmap_sections_on_project_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tutorial_steps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.string "title", null: false
    t.bigint "tutorial_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tutorial_id"], name: "index_tutorial_steps_on_tutorial_id"
  end

  create_table "tutorial_task_responses", force: :cascade do |t|
    t.boolean "accepted", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "tutorial_task_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["tutorial_task_id", "user_id"], name: "index_tutorial_task_responses_on_tutorial_task_id_and_user_id", unique: true
    t.index ["tutorial_task_id"], name: "index_tutorial_task_responses_on_tutorial_task_id"
    t.index ["user_id"], name: "index_tutorial_task_responses_on_user_id"
  end

  create_table "tutorial_tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.text "hint"
    t.bigint "next_step_if_accepted_id"
    t.bigint "next_step_if_rejected_id"
    t.integer "position", default: 0, null: false
    t.bigint "tutorial_step_id", null: false
    t.datetime "updated_at", null: false
    t.index ["next_step_if_accepted_id"], name: "index_tutorial_tasks_on_next_step_if_accepted_id"
    t.index ["next_step_if_rejected_id"], name: "index_tutorial_tasks_on_next_step_if_rejected_id"
    t.index ["tutorial_step_id"], name: "index_tutorial_tasks_on_tutorial_step_id"
  end

  create_table "tutorials", force: :cascade do |t|
    t.bigint "area_id", null: false
    t.datetime "created_at", null: false
    t.string "icon"
    t.integer "position", default: 0, null: false
    t.boolean "public", default: false, null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["area_id", "slug"], name: "index_tutorials_on_area_id_and_slug", unique: true
    t.index ["area_id"], name: "index_tutorials_on_area_id"
    t.index ["public"], name: "index_tutorials_on_public"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", default: "", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "webhook_deliveries", force: :cascade do |t|
    t.bigint "announcement_id", null: false
    t.datetime "created_at", null: false
    t.string "error_message"
    t.text "response_body"
    t.integer "status_code"
    t.boolean "success", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "webhook_id", null: false
    t.index ["announcement_id"], name: "index_webhook_deliveries_on_announcement_id"
    t.index ["webhook_id"], name: "index_webhook_deliveries_on_webhook_id"
  end

  create_table "webhooks", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.string "secret", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["active"], name: "index_webhooks_on_active"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "announcements", "users"
  add_foreign_key "api_token_areas", "api_tokens"
  add_foreign_key "api_token_areas", "areas"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "areas", "areas", column: "parent_id"
  add_foreign_key "chart_columns", "chart_tables"
  add_foreign_key "chart_indices", "chart_tables"
  add_foreign_key "chart_relationships", "chart_columns", column: "from_chart_column_id"
  add_foreign_key "chart_relationships", "chart_columns", column: "to_chart_column_id"
  add_foreign_key "chart_relationships", "charts"
  add_foreign_key "chart_tables", "charts"
  add_foreign_key "charts", "areas"
  add_foreign_key "pages", "areas"
  add_foreign_key "pages", "users"
  add_foreign_key "roadmap_cards", "roadmap_sections"
  add_foreign_key "roadmap_sections", "projects"
  add_foreign_key "sessions", "users"
  add_foreign_key "tutorial_steps", "tutorials"
  add_foreign_key "tutorial_task_responses", "tutorial_tasks"
  add_foreign_key "tutorial_task_responses", "users"
  add_foreign_key "tutorial_tasks", "tutorial_steps"
  add_foreign_key "tutorial_tasks", "tutorial_steps", column: "next_step_if_accepted_id"
  add_foreign_key "tutorial_tasks", "tutorial_steps", column: "next_step_if_rejected_id"
  add_foreign_key "tutorials", "areas"
  add_foreign_key "webhook_deliveries", "announcements"
  add_foreign_key "webhook_deliveries", "webhooks"
end
