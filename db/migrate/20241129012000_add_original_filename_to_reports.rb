class AddOriginalFilenameToReports < ActiveRecord::Migration[7.0]
  def change
    add_column :reports, :original_filename, :string, comment: "用户上传时的原始文件名"
  end
end

