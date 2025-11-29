# Railway 生产环境配置
require "active_support/core_ext/integer/time"

Rails.application.configure do
  # 基础生产配置
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  
  # Railway 特定配置
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/health" } } }
  
  # 数据库配置
  config.active_record.database_selector = { delay: 2.seconds }
  config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
  config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
  
  # 缓存配置
  config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] || ENV['REDIS_TLS_URL'] }
  
  # 文件存储配置
  config.active_storage.service = :railway
  config.active_storage.variant_processor = :mini_magick
  
  # 日志配置
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }
  
  config.log_tags = [:request_id]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym
  
  # 国际化配置
  config.i18n.fallbacks = true
  config.time_zone = "UTC"
  
  # 安全头配置
  config.force_ssl = true
  config.ssl_options = {
    redirect: {
      exclude: ->(request) {
        request.path == "/health" || request.path == "/up"
      }
    }
  }
  
  # 资产配置
  config.assets.compile = false
  config.assets.digest = true
  config.assets.version = '1.0'
  
  # 性能优化
  config.middleware.use Rack::Deflater
  config.middleware.use Rack::Timeout, service_timeout: 30
  
  # 健康检查
  config.middleware.use Rack::Health, path: "/health"
  
  # 允许的主机
  config.hosts = nil  # 允许所有主机访问
  
  # 文件上传限制
  config.middleware.use ActionDispatch::Flash
  config.middleware.use ActionDispatch::Cookies
  config.middleware.use ActionDispatch::Session::CookieStore
  config.middleware.use ActionDispatch::ContentSecurityPolicy::Middleware
  config.middleware.use ActionDispatch::PermissionsPolicy::Middleware
  
  # 速率限制
  config.middleware.use Rack::Attack do
    throttle("req/ip", limit: 100, window: 1.minute) do |req|
      req.ip
    end
    
    throttle("login/ip", limit: 5, window: 20.minutes) do |req|
      req.ip if req.path == "/login" && req.post?
    end
  end
end