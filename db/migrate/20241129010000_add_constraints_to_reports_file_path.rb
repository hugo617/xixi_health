class AddConstraintsToReportsFilePath < ActiveRecord::Migration[7.0]
  def change
    # 为 file_path 添加复合索引，提升按用户+文件路径查询的性能
    add_index :reports, %i[user_id file_path], name: "idx_reports_user_file_path"

    # 基础格式约束：
    # - 不允许空字符串
    # - 禁止路径遍历符号（../ 或 ..\）
    # - 禁止外部 URL（以 http:// 或 https:// 开头）
    add_check_constraint :reports,
                         "file_path <> '' " \
                           "AND file_path NOT LIKE '%../%' " \
                           "AND file_path NOT LIKE '%..\\\\%' " \
                           "AND file_path NOT LIKE 'http://%' " \
                           "AND file_path NOT LIKE 'https://%'",
                         name: "chk_reports_file_path_safety"
  end
end

