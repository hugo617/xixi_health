# frozen_string_literal: true

require "marcel"

module HealthReports
  # 报告文件下载服务
  # 负责权限校验、路径安全校验、频率限制和访问日志记录
  class DownloadFileService
    LEGACY_PREFIX = "/uploads/reports/".freeze

    def self.call(params = {})
      new(params).execute
    end

    def initialize(params = {})
      @report_id = params[:report_id]
      @current_user = params[:current_user]
      @ip_address = params[:ip_address]
      @inline = params[:inline].present?
    end

    def execute
      return failure("报告ID不能为空") if @report_id.blank?

      report = Report.not_deleted.find_by(id: @report_id)
      return failure("报告不存在") unless report

      auth_error = ensure_authorized(report)
      return failure(auth_error) if auth_error

      return failure("报告文件不存在") if report.file_path.blank?

      path_validation_error = validate_file_path(report.file_path)
      return failure(path_validation_error) if path_validation_error

      absolute_path = build_absolute_path(report.file_path)
      unless File.exist?(absolute_path)
        Rails.logger.warn "HealthReports::DownloadFileService - File not found for report #{report.id}: #{absolute_path}"
        return failure("报告文件不存在或已被删除")
      end

      rate_limit_error = check_download_rate_limit
      return failure(rate_limit_error) if rate_limit_error

      content_type = detect_content_type(absolute_path)
      filename = build_download_filename(report, absolute_path)
      disposition = @inline ? "inline" : "attachment"

      log_access(report, absolute_path, content_type, disposition)

      data = {
        report: report,
        file_path: absolute_path.to_s,
        filename: filename,
        content_type: content_type,
        disposition: disposition
      }

      { success: true, data: data, error: nil }
    rescue StandardError => e
      Rails.logger.error "HealthReports::DownloadFileService error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      failure("下载报告失败，请稍后重试")
    end

    private

    def failure(message)
      { success: false, data: nil, error: message }
    end

    def storage_base_dir
      configured = Rails.application.config.x.reports_storage
      base_dir = configured&.base_dir || Rails.root.join("storage", "reports")
      Pathname.new(base_dir)
    end

    def legacy_path?(file_path)
      file_path.to_s.start_with?(LEGACY_PREFIX)
    end

    def validate_file_path(file_path)
      value = file_path.to_s

      return "报告文件路径无效" if value.blank?
      return "报告文件路径包含非法字符" if value.include?("../") || value.include?("..\\")
      return "报告文件路径不允许使用URL" if value.start_with?("http://", "https://")

      nil
    end

    def build_absolute_path(file_path)
      value = file_path.to_s

      if legacy_path?(value)
        relative = value.delete_prefix(LEGACY_PREFIX)
        base_dir = Rails.root.join("public", "uploads", "reports")
        safe_join(base_dir, relative)
      else
        base_dir = storage_base_dir
        relative = Pathname.new(value)
        safe_join(base_dir, relative)
      end
    end

    def safe_join(base_dir, relative)
      base = base_dir.exist? ? base_dir.realpath : base_dir
      relative_path = relative.is_a?(Pathname) ? relative : Pathname.new(relative.to_s)

      candidate = base.join(relative_path).cleanpath

      # 使用 realpath 进一步确认路径归属（文件存在时）
      if candidate.exist?
        real = candidate.realpath
        unless real.to_s.start_with?(base.to_s)
          raise StandardError, "非法文件路径"
        end
        real
      else
        unless candidate.to_s.start_with?(base.to_s)
          raise StandardError, "非法文件路径"
        end
        candidate
      end
    end

    def detect_content_type(path)
      Marcel::MimeType.for(Pathname.new(path), name: File.basename(path)).to_s
    rescue StandardError => e
      Rails.logger.warn "HealthReports::DownloadFileService MIME detect fallback: #{e.class} - #{e.message}"
      "application/octet-stream"
    end

    def build_download_filename(report, absolute_path)
      base_name = File.basename(absolute_path)
      type_prefix = report.report_type.presence || "report"
      "#{type_prefix}_#{base_name}"
    rescue StandardError
      File.basename(absolute_path)
    end

    def ensure_authorized(report)
      config = Rails.application.config.x.reports_storage
      require_auth = config&.require_authentication

      return nil unless require_auth

      return "请先登录后再下载报告" if @current_user.blank?

      return nil if @current_user.admin?
      return nil if report.user_id == @current_user.id

      "您没有权限访问该报告"
    end

    def check_download_rate_limit
      config = Rails.application.config.x.reports_storage
      limit = config&.downloads_per_minute.to_i
      return nil if limit <= 0

      scope = FileAccessLog.where(action: "download")
      window_start = 1.minute.ago
      scope = scope.where("created_at >= ?", window_start)

      if @current_user.present?
        scope = scope.where(user_id: @current_user.id)
      elsif @ip_address.present?
        scope = scope.where(ip_address: @ip_address)
      else
        return nil
      end

      return "下载过于频繁，请稍后再试" if scope.count >= limit

      nil
    end

    def log_access(report, absolute_path, content_type, disposition)
      FileAccessLog.create!(
        user: @current_user,
        report: report,
        file_path: report.file_path.to_s,
        action: "download",
        ip_address: @ip_address
      )
    rescue StandardError => e
      Rails.logger.warn "HealthReports::DownloadFileService log access warning: #{e.class} - #{e.message}"
    end
  end
end
