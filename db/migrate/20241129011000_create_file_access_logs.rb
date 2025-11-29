class CreateFileAccessLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :file_access_logs do |t|
      t.references :user, null: true, foreign_key: true
      t.references :report, null: true, foreign_key: true

      t.string :file_path, null: false, comment: "访问的报告文件路径"
      t.string :action, null: false, default: "download", comment: "访问类型，如 download"
      t.string :ip_address, comment: "访问者IP地址"

      t.timestamps
    end

    add_index :file_access_logs, %i[user_id created_at], name: "idx_file_access_logs_user_time"
    add_index :file_access_logs, %i[report_id created_at], name: "idx_file_access_logs_report_time"
  end
end

