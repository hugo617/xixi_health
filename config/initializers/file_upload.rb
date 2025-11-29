# frozen_string_literal: true

# 文件上传配置初始化文件
# 配置大文件上传相关的设置

Rails.application.config.to_prepare do
  # 配置文件上传大小限制
  Rails.application.config.file_upload_max_size = 200.megabytes
  
  # 配置允许的文件类型
  Rails.application.config.allowed_file_types = %w[
    application/pdf
    image/jpeg
    image/png
    image/jpg
  ].freeze
  
  # 配置文件上传超时时间（秒）
  Rails.application.config.file_upload_timeout = 300
  
  # 配置临时文件目录
  Rails.application.config.temp_file_path = Rails.root.join('tmp', 'uploads')
  
  # 确保临时目录存在
  FileUtils.mkdir_p(Rails.application.config.temp_file_path) unless File.exist?(Rails.application.config.temp_file_path)
end

# 配置日志级别，避免大文件上传时产生过多日志
if Rails.env.production?
  Rails.application.config.log_level = :info
else
  Rails.application.config.log_level = :debug
end

# 配置ActionDispatch以支持大文件上传
Rails.application.config.action_dispatch.max_request_body_size = 200.megabytes