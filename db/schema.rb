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

ActiveRecord::Schema[7.2].define(version: 2024_11_29_012000) do
  create_table "file_access_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "report_id"
    t.string "file_path", null: false, comment: "访问的报告文件路径"
    t.string "action", default: "download", null: false, comment: "访问类型，如 download"
    t.string "ip_address", comment: "访问者IP地址"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id", "created_at"], name: "idx_file_access_logs_report_time"
    t.index ["report_id"], name: "index_file_access_logs_on_report_id"
    t.index ["user_id", "created_at"], name: "idx_file_access_logs_user_time"
    t.index ["user_id"], name: "index_file_access_logs_on_user_id"
  end

  create_table "reports", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false, comment: "关联用户ID"
    t.string "report_type", null: false, comment: "报告类型：protein_test, gene_test等"
    t.string "file_path", null: false, comment: "报告文件存储路径或URL"
    t.string "status", default: "pending_generation", null: false, comment: "报告状态：进度类(待生成/审核中)/结果正常类/结果异常类(轻/中/重度)/特殊类(待补充/待修订)"
    t.datetime "report_date", comment: "报告生成日期"
    t.integer "file_size", comment: "报告文件大小（字节）"
    t.text "description", comment: "报告描述或备注"
    t.datetime "deleted_at", comment: "软删除时间戳"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "original_filename", comment: "用户上传时的原始文件名"
    t.index ["deleted_at"], name: "idx_reports_deleted_at"
    t.index ["file_size"], name: "idx_reports_file_size"
    t.index ["report_date"], name: "idx_reports_date"
    t.index ["report_type"], name: "idx_reports_type"
    t.index ["status"], name: "idx_reports_status"
    t.index ["user_id", "file_path"], name: "idx_reports_user_file_path"
    t.index ["user_id", "report_type"], name: "idx_reports_user_type"
    t.index ["user_id"], name: "index_reports_on_user_id"
    t.check_constraint "(`file_path` <> _utf8mb4'') and (not((`file_path` like _utf8mb4'%../%'))) and (not((`file_path` like _utf8mb4'%..\\\\\\\\%'))) and (not((`file_path` like _utf8mb4'http://%'))) and (not((`file_path` like _utf8mb4'https://%')))", name: "chk_reports_file_path_safety"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "nickname", null: false
    t.string "email", null: false
    t.string "phone", null: false
    t.string "membership_type", default: "none", null: false
    t.string "role", default: "user", null: false
    t.string "password_digest", null: false
    t.string "status", default: "active", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["membership_type"], name: "index_users_on_membership_type"
    t.index ["phone"], name: "index_users_on_phone", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["status"], name: "index_users_on_status"
  end

  add_foreign_key "file_access_logs", "reports"
  add_foreign_key "file_access_logs", "users"
  add_foreign_key "reports", "users"
end
