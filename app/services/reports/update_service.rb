# app/services/reports/update_report.rb
# 报告更新服务
# 处理健康报告更新的业务逻辑
#
# 遵循Service Object模式，负责业务逻辑、数据验证和数据库操作

require "fileutils"

module Reports
  class UpdateService
    # 允许更新的字段
    ALLOWED_UPDATE_FIELDS = %i[report_type status file_path report_date file_size description].freeze
    
    # 默认文件大小限制
    MAX_FILE_SIZE = 200.megabytes
    
    # 允许的文件扩展名
    ALLOWED_FILE_EXTENSIONS = %w[pdf doc docx txt xls xlsx].freeze

    # 上传目录（相对于 Rails.root）
    UPLOAD_BASE_DIR = Rails.root.join("public", "uploads", "reports").freeze

    # 单个上传文件的最大大小（200MB）
    MAX_UPLOAD_FILE_SIZE = 200.megabytes
    
    # 服务对象的入口点
    # @param params [Hash] 更新参数，包含 report_id 和需要更新的字段
    # @return [Hash] 标准化服务响应格式 { success: Boolean, data: Any, error: String/nil }
    def self.call(params = {})
      new(params).execute
    end

    # 初始化服务
    # @param params [Hash] 更新参数
    def initialize(params = {})
      @report_id = params[:report_id]
      report_params = params[:report] || {}
      @uploaded_file = report_params[:file] || report_params["file"]
      @update_params = report_params.is_a?(Hash) ? report_params.symbolize_keys.slice(*ALLOWED_UPDATE_FIELDS) : {}
      @update_params.delete(:file_path) if use_secure_storage?
    end

    # 执行报告更新逻辑
    # @return [Hash] 标准化服务响应格式
    def execute
      # 验证报告ID
      return { success: false, data: nil, error: "报告ID不能为空" } if @report_id.blank?
      
      # 查找报告
      report = Report.not_deleted.find_by(id: @report_id)
      return { success: false, data: nil, error: "报告不存在" } unless report
      
      # 验证更新参数
      return { success: false, data: nil, error: "没有提供有效的更新字段" } if @update_params.empty?

      # 如果有上传文件，先处理文件上传，生成并填充 file_path / file_size
      upload_result = handle_file_upload(report)
      return upload_result unless upload_result[:success]
      
      # 验证更新字段
      validation_result = validate_update_params(report)
      return validation_result unless validation_result[:success]
      
      # 更新报告信息
      if report.update(@update_params)
        Rails.logger.info "Reports::UpdateReport - Report updated successfully: ID #{report.id}"
        {
          success: true,
          data: serialize_report(report),
          error: nil
        }
      else
        {
          success: false,
          data: nil,
          error: report.errors.full_messages.join(", ")
        }
      end
    rescue ActiveRecord::RecordNotFound
      { success: false, data: nil, error: "报告不存在" }
    rescue ActiveRecord::RecordInvalid => e
      { success: false, data: nil, error: e.record.errors.full_messages.join(", ") }
    rescue StandardError => e
      Rails.logger.error "Reports::UpdateReport error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, data: nil, error: "更新失败，请稍后重试" }
    end

    private

    # 处理文件上传（可选）
    # @param report [Report] 报告对象
    # @return [Hash] 标准化服务响应格式；如果没有上传文件则返回 success: true
    def handle_file_upload(report)
      return { success: true, data: nil, error: nil } if @uploaded_file.blank?

      if use_secure_storage?
        upload_result = HealthReports::UploadFileService.call(
          user_id: report.user_id,
          file: @uploaded_file,
          existing_file_path: report.file_path
        )
        return upload_result unless upload_result[:success]

        data = upload_result[:data]
        @update_params[:file_path] = data[:file_path]
        @update_params[:file_size] = data[:file_size]
        @update_params[:original_filename] = data[:original_filename]

        return { success: true, data: nil, error: nil }
      end

      unless pdf_file?(@uploaded_file)
        return { success: false, data: nil, error: "只支持上传PDF文件" }
      end

      if @uploaded_file.size.to_i > MAX_UPLOAD_FILE_SIZE
        return { success: false, data: nil, error: "文件大小不能超过#{MAX_UPLOAD_FILE_SIZE / 1.megabyte}MB" }
      end

      FileUtils.mkdir_p(UPLOAD_BASE_DIR) unless Dir.exist?(UPLOAD_BASE_DIR)

      original_filename = @uploaded_file.original_filename.to_s
      sanitized_name = sanitize_filename(original_filename)
      timestamp = Time.current.strftime("%Y%m%d%H%M%S")
      stored_name = "#{timestamp}_#{sanitized_name}"

      absolute_path = UPLOAD_BASE_DIR.join(stored_name)
      relative_path = "/uploads/reports/#{stored_name}"

      File.open(absolute_path, "wb") do |file|
        file.write(@uploaded_file.read)
      end

      # 删除旧文件（如果在受管目录内）
      delete_file_if_exists(report.file_path)

      @update_params[:file_path] = relative_path
      @update_params[:file_size] = @uploaded_file.size.to_i
      @update_params[:original_filename] = original_filename

      { success: true, data: nil, error: nil }
    rescue StandardError => e
      Rails.logger.error "Reports::UpdateService file upload error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, data: nil, error: "文件上传失败，请稍后重试" }
    end

    # 验证更新参数
    # @param report [Report] 报告对象
    # @return [Hash] 验证结果
    def validate_update_params(report)
      # 验证报告类型
      if @update_params[:report_type].present?
        valid_report_types = %w[protein_test gene_test blood_test urine_test other_test]
        unless valid_report_types.include?(@update_params[:report_type])
          return { success: false, data: nil, error: "无效的报告类型" }
        end
      end
      
      # 验证状态
      if @update_params[:status].present?
        valid_statuses = %w[pending_generation under_review normal_result abnormal_mild abnormal_moderate abnormal_severe pending_supplement pending_revision]
        unless valid_statuses.include?(@update_params[:status])
          return { success: false, data: nil, error: "无效的报告状态" }
        end
      end
      
      # 验证文件路径格式
      if @update_params[:file_path].present?
        unless valid_file_path?(@update_params[:file_path])
          return { success: false, data: nil, error: "文件路径格式不正确，必须是有效的文件路径" }
        end
      end
      
      # 验证文件大小
      if @update_params[:file_size].present?
        file_size = @update_params[:file_size].to_i
        if file_size < 0
          return { success: false, data: nil, error: "文件大小不能为负数" }
        end
        
        if file_size > MAX_FILE_SIZE
          return { success: false, data: nil, error: "文件大小不能超过#{MAX_FILE_SIZE / 1.megabyte}MB" }
        end
      end
      
      # 验证报告日期
      if @update_params[:report_date].present?
        begin
          report_date = Time.parse(@update_params[:report_date].to_s)
          if report_date > Time.current
            return { success: false, data: nil, error: "报告日期不能是未来日期" }
          end
        rescue ArgumentError
          return { success: false, data: nil, error: "报告日期格式不正确" }
        end
      end
      
      # 验证描述长度
      if @update_params[:description].present? && @update_params[:description].length > 500
        return { success: false, data: nil, error: "报告描述不能超过500个字符" }
      end
      
      { success: true, data: nil, error: nil }
    end

    # 验证文件路径格式
    # @param file_path [String] 文件路径
    # @return [Boolean] 是否有效
    def valid_file_path?(file_path)
      return false if file_path.blank?

      # 禁止路径遍历
      return false if file_path.include?("../") || file_path.include?("..\\")

      extension = File.extname(file_path).downcase.delete_prefix(".")
      return false unless ALLOWED_FILE_EXTENSIONS.include?(extension)

      # 兼容两种格式：
      # 1. 旧格式：/uploads/reports/xxxx.ext
      # 2. 新格式：相对路径，例如 user_1/uuid_sanitized.ext
      legacy_pattern = %r{\A\/uploads\/reports\/.+\.(#{ALLOWED_FILE_EXTENSIONS.join('|')})\z}i
      new_pattern = /\A[\w\-\u4e00-\u9fa5\/]+\.(#{ALLOWED_FILE_EXTENSIONS.join('|')})\z/i

      file_path.match?(legacy_pattern) || file_path.match?(new_pattern)
    end

    # 判断上传文件是否为 PDF
    # @param uploaded_file [ActionDispatch::Http::UploadedFile]
    # @return [Boolean]
    def pdf_file?(uploaded_file)
      return false if uploaded_file.blank?

      content_type = uploaded_file.content_type.to_s.downcase
      return true if content_type == "application/pdf"

      File.extname(uploaded_file.original_filename.to_s).downcase == ".pdf"
    end

    # 清理文件名，防止路径遍历
    # @param filename [String]
    # @return [String]
    def sanitize_filename(filename)
      base = File.basename(filename.to_s)
      base.gsub(/[^0-9A-Za-z.\-]/, "_")
    end

    # 删除物理文件（仅限受管目录）
    # @param file_path [String]
    def delete_file_if_exists(file_path)
      return if file_path.blank?
      return unless file_path.start_with?("/uploads/reports/")

      absolute_path = Rails.root.join("public", file_path.delete_prefix("/"))
      File.delete(absolute_path) if File.exist?(absolute_path)
    rescue StandardError => e
      Rails.logger.warn "Reports::UpdateService delete file warning: #{e.class} - #{e.message}"
    end

    def use_secure_storage?
      config = Rails.application.config.x.reports_storage
      config&.mode.to_s == "secure"
    end

    # 序列化报告数据
    # @param report [Report] 报告对象
    # @return [Hash] 序列化后的报告数据
    def serialize_report(report)
      report.as_json(
        only: [:id, :user_id, :report_type, :status, :file_path, :report_date,
               :file_size, :description, :original_filename, :created_at, :updated_at],
        methods: [:active?, :normal_result?, :abnormal?, :abnormal_mild?, 
                 :abnormal_moderate?, :abnormal_severe?, :in_progress?, 
                 :final_result?, :formatted_file_size, :report_age_in_days],
        include: {
          user: { only: [:id, :nickname, :email] }
        }
      )
    end
  end
end
