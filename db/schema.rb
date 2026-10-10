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

ActiveRecord::Schema[8.1].define(version: 2026_10_10_223404) do
  create_table "call_records", force: :cascade do |t|
    t.datetime "started_at", null: false
    t.string "from_number", null: false
    t.string "to_number", null: false
    t.integer "duration_seconds", null: false
    t.string "cell_tower_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["started_at", "from_number", "to_number"], name: "index_call_records_uniqueness", unique: true
    t.index ["started_at"], name: "index_call_records_on_started_at"
  end
end
