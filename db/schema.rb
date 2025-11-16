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

ActiveRecord::Schema[7.1].define(version: 2025_11_16_153958) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.jsonb "audit_changes", default: {}
    t.string "ip_address"
    t.string "user_agent"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "availability_schedules", force: :cascade do |t|
    t.bigint "service_id", null: false
    t.integer "day_of_week", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.boolean "active", default: true
    t.date "valid_from"
    t.date "valid_until"
    t.jsonb "recurring_pattern", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_availability_schedules_on_active"
    t.index ["service_id", "day_of_week"], name: "index_availability_schedules_on_service_id_and_day_of_week"
    t.index ["service_id"], name: "index_availability_schedules_on_service_id"
    t.index ["valid_from", "valid_until"], name: "index_availability_schedules_on_valid_from_and_valid_until"
  end

  create_table "blocked_dates", force: :cascade do |t|
    t.bigint "service_id"
    t.date "blocked_date", null: false
    t.time "start_time"
    t.time "end_time"
    t.string "reason"
    t.boolean "recurring_yearly", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked_date"], name: "index_blocked_dates_on_blocked_date"
    t.index ["service_id", "blocked_date"], name: "index_blocked_dates_on_service_id_and_blocked_date"
    t.index ["service_id"], name: "index_blocked_dates_on_service_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "service_id", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.string "status", default: "pending", null: false
    t.decimal "amount", precision: 10, scale: 2
    t.string "currency", default: "USD"
    t.string "booking_reference", null: false
    t.text "notes"
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_id"
    t.datetime "confirmed_at"
    t.datetime "reminder_sent_at"
    t.jsonb "metadata", default: {}
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_reference"], name: "index_bookings_on_booking_reference", unique: true
    t.index ["cancelled_by_id"], name: "index_bookings_on_cancelled_by_id"
    t.index ["deleted_at"], name: "index_bookings_on_deleted_at"
    t.index ["service_id", "start_time"], name: "index_bookings_on_service_id_and_start_time"
    t.index ["service_id"], name: "index_bookings_on_service_id"
    t.index ["start_time", "end_time"], name: "index_bookings_on_start_time_and_end_time"
    t.index ["status"], name: "index_bookings_on_status"
    t.index ["user_id"], name: "index_bookings_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "user_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", default: "USD"
    t.string "status", null: false
    t.string "payment_method"
    t.string "stripe_payment_intent_id"
    t.string "stripe_charge_id"
    t.string "stripe_refund_id"
    t.jsonb "stripe_response", default: {}
    t.text "failure_reason"
    t.datetime "paid_at"
    t.datetime "refunded_at"
    t.decimal "refund_amount", precision: 10, scale: 2
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id", "status"], name: "index_payments_on_booking_id_and_status"
    t.index ["booking_id"], name: "index_payments_on_booking_id"
    t.index ["status"], name: "index_payments_on_status"
    t.index ["stripe_charge_id"], name: "index_payments_on_stripe_charge_id"
    t.index ["stripe_payment_intent_id"], name: "index_payments_on_stripe_payment_intent_id"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "services", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "duration_minutes", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.string "currency", default: "USD"
    t.boolean "active", default: true
    t.integer "buffer_time_minutes", default: 0
    t.integer "max_advance_days", default: 60
    t.integer "min_advance_hours", default: 24
    t.jsonb "settings", default: {}
    t.string "slug"
    t.string "color"
    t.integer "position"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_services_on_active"
    t.index ["deleted_at"], name: "index_services_on_deleted_at"
    t.index ["position"], name: "index_services_on_position"
    t.index ["slug"], name: "index_services_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name"
    t.string "phone"
    t.boolean "admin", default: false
    t.string "time_zone", default: "UTC"
    t.datetime "last_login_at"
    t.string "magic_link_token"
    t.datetime "magic_link_sent_at"
    t.datetime "magic_link_confirmed_at"
    t.string "stripe_customer_id"
    t.jsonb "preferences", default: {}
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["magic_link_token"], name: "index_users_on_magic_link_token", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id"
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "availability_schedules", "services"
  add_foreign_key "blocked_dates", "services"
  add_foreign_key "bookings", "services"
  add_foreign_key "bookings", "users"
  add_foreign_key "bookings", "users", column: "cancelled_by_id"
  add_foreign_key "payments", "bookings"
  add_foreign_key "payments", "users"
end
