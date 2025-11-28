# app/services/reports/create_report.rb
# 报告创建服务
# 处理健康报告创建的业务逻辑

require "fileutils"

module Reports
  class CreateService
    # 允许创建的字段
    ALLOWED_CREATE_FIELDS = %i[user_id report_type status file_path report_date file_size description].freeze
    
    # 默认文件大小限制
    MAX_FILE_SIZE = 100.megabytes
    
    # 允许的文件扩展名
    ALLOWED_FILE_EXTENSIONS = %w[pdf doc docx txt xls xlsx].freeze

    # 上传目录（相对于 Rails.root）
    UPLOAD_BASE_DIR = Rails.root.join("public", "uploads", "reports").freeze

    # 单个上传文件的最大大小（10MB）
    MAX_UPLOAD_FILE_SIZE = 10.megabytes
    
    # 服务对象的入口点
    # @param params [Hash] 创建参数
    # @return [Hash] 标准化服务响应格式 { success: Boolean, data: Any, error: String/nil }
    def self.call(params = {})
      new(params).execute
    end

    # 初始化服务
    # @param params [Hash] 创建参数
    def initialize(params = {})
      report_params = params[:report] || {}
      @uploaded_file = report_params[:file] || report_params["file"]
      @create_params = report_params.symbolize_keys.slice(*ALLOWED_CREATE_FIELDS)
      # 设置默认值
      @create_params[:status] ||= 'pending_generation'
      @create_params[:report_date] ||= Time.current
      @create_params[:file_size] ||= 0
    end

    # 执行报告创建逻辑
    # @return [Hash] 标准化服务响应格式
    def execute
      # 如果有上传文件，先处理文件上传，生成并填充 file_path / file_size
      upload_result = handle_file_upload
      return upload_result unless upload_result[:success]

      # 验证创建参数
      validation_result = validate_create_params
      return validation_result unless validation_result[:success]
      
      # 创建报告
      report = Report.new(@create_params)
      
      if report.save
        Rails.logger.info "Reports::CreateReport - Report created successfully: ID #{report.id}, User ID: #{report.user_id}, Type: #{report.report_type}"
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
    rescue ActiveRecord::RecordInvalid => e
      { success: false, data: nil, error: e.record.errors.full_messages.join(", ") }
    rescue StandardError => e
      Rails.logger.error "Reports::CreateReport error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, data: nil, error: "创建报告失败，请稍后重试" }
    end

    private

    # 处理文件上传（可选）
    # @return [Hash] 标准化服务响应格式；如果没有上传文件则返回 success: true
    def handle_file_upload
      return { success: true, data: nil, error: nil } if @uploaded_file.blank?

      unless pdf_file?(@uploaded_file)
        return { success: false, data: nil, error: "只支持上传PDF文件" }
      end

      if @uploaded_file.size.to_i > MAX_UPLOAD_FILE_SIZE
        return { success: false, data: nil, error: "文件大小不能超过#{MAX_UPLOAD_FILE_SIZE / 1.megabyte}MB" }
      end

      FileUtils.mkdir_p(UPLOAD_BASE_DIR) unless Dir.exist?(UPLOAD_BASE_DIR)

      sanitized_name = sanitize_filename(@uploaded_file.original_filename)
      timestamp = Time.current.strftime("%Y%m%d%H%M%S")
      stored_name = "#{timestamp}_#{sanitized_name}"

      absolute_path = UPLOAD_BASE_DIR.join(stored_name)
      relative_path = "/uploads/reports/#{stored_name}"

      File.open(absolute_path, "wb") do |file|
        file.write(@uploaded_file.read)
      end

      @create_params[:file_path] = relative_path
      @create_params[:file_size] = @uploaded_file.size.to_i

      { success: true, data: nil, error: nil }
    rescue StandardError => e
      Rails.logger.error "Reports::CreateService file upload error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, data: nil, error: "文件上传失败，请稍后重试" }
    end

    # 验证创建参数
    # @return [Hash] 验证结果
    def validate_create_params
      # 检查必需字段
      required_fields = [:user_id, :report_type, :file_path]
      missing_fields = required_fields.select { |field| @create_params[field].blank? }
      
      if missing_fields.any?
        field_names = {
          user_id: "用户ID",
          report_type: "报告类型",
          file_path: "文件路径"
        }
        missing_names = missing_fields.map { |f| field_names[f] }.join("、")
        return { success: false, data: nil, error: "缺少必需字段: #{missing_names}" }
      end
      
      # 验证用户是否存在
      unless User.exists?(id: @create_params[:user_id])
        return { success: false, data: nil, error: "用户不存在" }
      end
      
      # 验证报告类型
      valid_report_types = %w[protein_test gene_test blood_test urine_test other_test]
      unless valid_report_types.include?(@create_params[:report_type])
        return { success: false, data: nil, error: "无效的报告类型" }
      end
      
      # 验证状态
      valid_statuses = %w[pending_generation under_review normal_result abnormal_mild abnormal_moderate abnormal_severe pending_supplement pending_revision]
      if @create_params[:status].present? && !valid_statuses.include?(@create_params[:status])
        return { success: false, data: nil, error: "无效的报告状态" }
      end
      
      # 验证文件路径格式
      unless valid_file_path?(@create_params[:file_path])
        return { success: false, data: nil, error: "文件路径格式不正确，必须是有效的文件路径" }
      end
      
      # 验证文件大小
      if @create_params[:file_size].present?
        file_size = @create_params[:file_size].to_i
        if file_size < 0
          return { success: false, data: nil, error: "文件大小不能为负数" }
        end
        
        if file_size > MAX_FILE_SIZE
          return { success: false, data: nil, error: "文件大小不能超过#{MAX_FILE_SIZE / 1.megabyte}MB" }
        end
      end
      
      # 验证报告日期
      if @create_params[:report_date].present?
        begin
          report_date = Time.parse(@create_params[:report_date].to_s)
          if report_date > Time.current
            return { success: false, data: nil, error: "报告日期不能是未来日期" }
          end
        rescue ArgumentError
          return { success: false, data: nil, error: "报告日期格式不正确" }
        end
      end
      
      # 验证描述长度
      if @create_params[:description].present? && @create_params[:description].length > 500
        return { success: false, data: nil, error: "报告描述不能超过500个字符" }
      end
      
      { success: true, data: nil, error: nil }
    end

    # 验证文件路径格式
    # @param file_path [String] 文件路径
    # @return [Boolean] 是否有效
    def valid_file_path?(file_path)
      return false if file_path.blank?
      
      # 检查路径格式和扩展名
      extension = File.extname(file_path).downcase[1..-1]
      file_path.match?(/\A\/.+\.(#{ALLOWED_FILE_EXTENSIONS.join('|')})\z/i) && ALLOWED_FILE_EXTENSIONS.include?(extension)
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

    # 序列化报告数据
    # @param report [Report] 报告对象
    # @return [Hash] 序列化后的报告数据
    def serialize_report(report)
      report.as_json(
        only: [:id, :user_id, :report_type, :status, :file_path, :report_date, 
               :file_size, :description, :created_at, :updated_at],
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
