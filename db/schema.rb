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

ActiveRecord::Schema[8.0].define(version: 2025_08_20_165742) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "loans", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.decimal "interest_rate", precision: 5, scale: 4, null: false
    t.decimal "total_amount_due", precision: 10, scale: 2, null: false
    t.integer "term_days", null: false
    t.date "due_date", null: false
    t.string "status", default: "pending"
    t.string "purpose"
    t.string "loan_type", default: "personal"
    t.decimal "daily_penalty_rate", precision: 5, scale: 4, default: "0.005"
    t.json "approval_metadata"
    t.string "disbursement_method"
    t.string "disbursement_account"
    t.datetime "approved_at"
    t.datetime "disbursed_at"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["due_date"], name: "index_loans_on_due_date"
    t.index ["status"], name: "index_loans_on_status"
    t.index ["user_id", "status"], name: "index_loans_on_user_id_and_status"
    t.index ["user_id"], name: "index_loans_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "loan_id", null: false
    t.bigint "user_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "payment_method"
    t.string "payment_reference"
    t.string "status", default: "pending"
    t.json "payment_metadata"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["loan_id", "status"], name: "index_payments_on_loan_id_and_status"
    t.index ["loan_id"], name: "index_payments_on_loan_id"
    t.index ["payment_reference"], name: "index_payments_on_payment_reference"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "promo_codes", force: :cascade do |t|
    t.string "code", null: false
    t.string "promo_type"
    t.decimal "discount_percentage", precision: 5, scale: 2
    t.decimal "discount_amount", precision: 10, scale: 2
    t.decimal "bonus_credit", precision: 10, scale: 2
    t.integer "usage_limit"
    t.integer "used_count", default: 0
    t.date "valid_from"
    t.date "valid_until"
    t.boolean "active", default: true
    t.json "conditions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_promo_codes_on_code", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "phone_number", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.date "date_of_birth"
    t.string "address"
    t.string "employment_status"
    t.decimal "monthly_income", precision: 10, scale: 2
    t.decimal "credit_limit", precision: 10, scale: 2, default: "5000.0"
    t.integer "credit_score", default: 0
    t.string "status", default: "pending"
    t.string "referral_code"
    t.string "referred_by_code"
    t.json "kyc_documents"
    t.boolean "kyc_verified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
    t.index ["referral_code"], name: "index_users_on_referral_code", unique: true
    t.index ["referred_by_code"], name: "index_users_on_referred_by_code"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "loans", "users"
  add_foreign_key "payments", "loans"
  add_foreign_key "payments", "users"
end
