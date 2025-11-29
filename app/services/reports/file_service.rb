# app/services/reports/file_service.rb
# 报告文件访问服务
# 负责根据报告ID定位物理PDF文件，并做基础验证

module Reports
  class FileService
    LEGACY_PREFIX = "/uploads/reports/".freeze

    # 服务对象入口
    # @param params [Hash] 含 report_id
    # @return [Hash] { success: Boolean, data: Any, error: String/nil }
    def self.call(params = {})
      new(params).execute
    end

    def initialize(params = {})
      @report_id = params[:report_id]
    end

    def execute
      return { success: false, data: nil, error: "报告ID不能为空" } if @report_id.blank?

      report = Report.not_deleted.find_by(id: @report_id)
      return { success: false, data: nil, error: "报告不存在" } unless report

      if report.file_path.blank?
        return { success: false, data: nil, error: "报告文件不存在" }
      end

      unless managed_report_path?(report.file_path)
        Rails.logger.warn "Reports::FileService - Invalid file path for report #{report.id}: #{report.file_path}"
        return { success: false, data: nil, error: "报告文件路径无效" }
      end

      absolute_path = build_absolute_path(report.file_path)

      unless File.exist?(absolute_path)
        Rails.logger.warn "Reports::FileService - File not found for report #{report.id}: #{absolute_path}"
        return { success: false, data: nil, error: "报告文件不存在或已被删除" }
      end

      extension = File.extname(absolute_path).downcase
      unless extension == ".pdf"
        Rails.logger.warn "Reports::FileService - Unsupported file extension for report #{report.id}: #{extension}"
        return { success: false, data: nil, error: "当前仅支持预览PDF格式报告" }
      end

      data = {
        report: report,
        file_path: absolute_path.to_s,
        relative_url: report.file_path,
        filename: build_download_filename(report, absolute_path),
        content_type: "application/pdf"
      }

      { success: true, data: data, error: nil }
    rescue StandardError => e
      Rails.logger.error "Reports::FileService error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, data: nil, error: "加载报告文件失败，请稍后重试" }
    end

    private

    # 是否在受管上传目录下
    def managed_report_path?(file_path)
      return false if file_path.blank?

      value = file_path.to_s

      # 禁止路径遍历
      return false if value.include?("../") || value.include?("..\\")

      # 兼容旧的 /uploads/reports/ 前缀
      return true if value.start_with?(LEGACY_PREFIX)

      # 新的存储结构：相对于 storage/reports 的相对路径
      # 例如：user_1/a1b2c3d4-..._health_report.pdf
      value !~ %r{\A/} && value !~ %r{://}
    end

    # 构建物理路径
    def build_absolute_path(file_path)
      value = file_path.to_s

      if value.start_with?(LEGACY_PREFIX)
        base_dir = Rails.root.join("public", "uploads", "reports")
        relative = value.delete_prefix(LEGACY_PREFIX)
        safe_join(base_dir, relative)
      else
        base_dir = storage_base_dir
        relative = Pathname.new(value)
        safe_join(base_dir, relative)
      end
    end

    def storage_base_dir
      configured = Rails.application.config.x.reports_storage
      base_dir = configured&.base_dir || Rails.root.join("storage", "reports")
      Pathname.new(base_dir)
    end

    def safe_join(base_dir, relative)
      base = base_dir.exist? ? base_dir.realpath : base_dir
      relative_path = relative.is_a?(Pathname) ? relative : Pathname.new(relative.to_s)

      candidate = base.join(relative_path).cleanpath

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

    # 构建下载文件名
    def build_download_filename(report, absolute_path)
      base_name = File.basename(absolute_path)
      type_prefix = report.report_type.presence || "report"
      "#{type_prefix}_#{base_name}"
    rescue StandardError
      File.basename(absolute_path)
    end
  end
end
