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

ActiveRecord::Schema[8.1].define(version: 2026_10_11_000001) do
  create_table "call_records", force: :cascade do |t|
    t.datetime "started_at", null: false
    t.string "from_number", null: false
    t.string "to_number", null: false
    t.integer "duration_seconds", null: false
    t.string "cell_tower_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "import_id", null: false
    t.integer "source_line", null: false
    t.index ["import_id"], name: "index_call_records_on_import_id"
    t.index ["started_at", "from_number", "to_number"], name: "index_call_records_uniqueness", unique: true
    t.index ["started_at"], name: "index_call_records_on_started_at"
  end

  create_table "imports", force: :cascade do |t|
    t.string "filename", null: false
    t.string "sha256", null: false
    t.integer "byte_size", null: false
    t.string "error"
    t.integer "call_records_count", default: 0, null: false
    t.integer "rejected_rows_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sha256"], name: "index_imports_on_sha256"
  end

  create_table "rejected_rows", force: :cascade do |t|
    t.integer "import_id", null: false
    t.integer "line_number", null: false
    t.string "reason", null: false
    t.text "raw", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["import_id"], name: "index_rejected_rows_on_import_id"
  end

  add_foreign_key "call_records", "imports"
  add_foreign_key "rejected_rows", "imports"
end
