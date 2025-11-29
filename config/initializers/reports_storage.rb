# frozen_string_literal: true

# 全局配置：健康报告文件存储与访问策略
Rails.application.configure do
  config.x.reports_storage = ActiveSupport::OrderedOptions.new

  # 报告文件物理存储根目录
  # 默认使用 Rails.root/storage/reports
  config.x.reports_storage.base_dir =
    Rails.root.join("storage", "reports")

  # 存储模式：
  # - "legacy": 继续使用 public/uploads/reports（向后兼容）
  # - "secure": 使用 storage/reports，并通过 Service Object 访问
  # 默认启用 secure，新环境不再写入 /uploads/reports
  config.x.reports_storage.mode =
    ENV.fetch("REPORTS_STORAGE_MODE", "secure")

  # 是否强制下载需要登录与权限校验
  config.x.reports_storage.require_authentication =
    ActiveModel::Type::Boolean.new.cast(
      ENV.fetch("REPORTS_REQUIRE_AUTHENTICATION", "false")
    )

  # 每个用户每分钟允许的最大下载次数
  config.x.reports_storage.downloads_per_minute =
    ENV.fetch("REPORTS_DOWNLOADS_PER_MINUTE", "10").to_i
end
