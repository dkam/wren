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

ActiveRecord::Schema[8.1].define(version: 2026_10_21_232314) do
  create_table "claims", force: :cascade do |t|
    t.integer "list_id", null: false
    t.string "name", null: false
    t.string "session"
    t.string "note"
    t.string "host"
    t.datetime "seen_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["list_id", "name"], name: "index_claims_on_list_id_and_name", unique: true
    t.index ["list_id", "session"], name: "index_claims_on_list_id_and_session", unique: true
    t.index ["list_id"], name: "index_claims_on_list_id"
  end

  create_table "lists", force: :cascade do |t|
    t.string "token", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_lists_on_token", unique: true
  end

  create_table "names", force: :cascade do |t|
    t.integer "list_id", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["list_id", "value"], name: "index_names_on_list_id_and_value", unique: true
    t.index ["list_id"], name: "index_names_on_list_id"
  end

  add_foreign_key "claims", "lists"
  add_foreign_key "names", "lists"
end
