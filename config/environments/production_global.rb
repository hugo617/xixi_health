# 全球生产环境配置
require "active_support/core_ext/integer/time"

Rails.application.configure do
  # 基础生产环境配置
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  
  # 全球化优化配置
  config.force_ssl = true
  config.ssl_options = { 
    redirect: { 
      exclude: ->(request) { 
        request.path == "/up" || request.path == "/health" 
      } 
    } 
  }
  
  # CDN和资产优化
  config.asset_host = ENV.fetch("ASSET_HOST", nil)
  config.action_controller.asset_host = ENV.fetch("ASSET_HOST", nil)
  
  # 多地域时区支持
  config.time_zone = "UTC"
  config.active_record.default_timezone = :utc
  
  # 国际化配置
  config.i18n.fallbacks = [:en, :zh, :es, :fr, :de, :ja, :ko]
  config.i18n.available_locales = [:en, :zh, :es, :fr, :de, :ja, :ko, :pt, :ru, :ar]
  
  # 全球化缓存配置
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"),
    namespace: "xixi_health_global",
    expires_in: 1.day,
    race_condition_ttl: 10.seconds,
    pool_size: 20,
    pool_timeout: 5
  }
  
  # 会话存储配置
  config.session_store :redis_session_store, {
    key: "_xixi_health_session",
    redis: {
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/2"),
      namespace: "xixi_health:session",
      expire_after: 2.hours
    },
    secure: true,
    httponly: true,
    same_site: :lax
  }
  
  # 文件存储配置 - 使用云存储
  config.active_storage.service = ENV.fetch("STORAGE_SERVICE", "amazon").to_sym
  
  # 邮件配置 - 全球邮件服务
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS", "smtp.gmail.com"),
    port: ENV.fetch("SMTP_PORT", "587"),
    domain: ENV.fetch("SMTP_DOMAIN", "xixi-health.com"),
    user_name: ENV.fetch("SMTP_USERNAME"),
    password: ENV.fetch("SMTP_PASSWORD"),
    authentication: :plain,
    enable_starttls_auto: true
  }
  
  # 日志配置 - 结构化日志
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }
  
  config.log_tags = [:request_id, :remote_ip, :subdomain]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym
  
  # 安全配置
  config.hosts = ENV.fetch("ALLOWED_HOSTS", "").split(",")
  config.host_authorization = {
    exclude: ->(request) {
      request.path == "/up" || 
      request.path == "/health" ||
      request.path == "/robots.txt"
    }
  }
  
  # 性能优化
  config.middleware.use Rack::Deflater
  config.middleware.insert_before ActionDispatch::Static, Rack::Deflater
  
  # 文件上传优化
  config.active_storage.replace_on_assign_to_many = false
  config.middleware.use ActionDispatch::Cookies
  config.middleware.use ActionDispatch::Session::CookieStore
  
  # 健康检查端点
  config.middleware.use Rack::Health, path: "/health"
  
  # 数据库读写分离
  if ENV["DATABASE_REPLICA_URL"].present?
    config.active_record.database_selector = { delay: 2.seconds }
    config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
    config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
  end
  
  # 速率限制配置
  config.middleware.use Rack::Attack do
    throttle("req/ip", limit: 300, window: 5.minutes) do |req|
      req.ip
    end
    
    throttle("login/ip", limit: 5, window: 20.minutes) do |req|
      req.ip if req.path == "/login" && req.post?
    end
    
    throttle("api/ip", limit: 1000, window: 5.minutes) do |req|
      req.ip if req.path.start_with?("/api")
    end
  end
  
  # 全球化错误处理
  config.exceptions_app = self.routes
  
  # 时区智能路由
  config.middleware.use Rack::Timezone, default: "UTC"
  
  # 语言检测
  config.middleware.use Rack::LocaleDetector, default: :en
end