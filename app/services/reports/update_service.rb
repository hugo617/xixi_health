# app/services/reports/update_report.rb
# 报告更新服务
# 处理健康报告更新的业务逻辑
#
# 遵循Service Object模式，负责业务逻辑、数据验证和数据库操作

module Reports
  class UpdateService
    # 允许更新的字段
    ALLOWED_UPDATE_FIELDS = %i[report_type status file_path report_date file_size description].freeze
    
    # 默认文件大小限制
    MAX_FILE_SIZE = 100.megabytes
    
    # 允许的文件扩展名
    ALLOWED_FILE_EXTENSIONS = %w[pdf doc docx txt xls xlsx].freeze
    
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
      @update_params = report_params.is_a?(Hash) ? report_params.symbolize_keys.slice(*ALLOWED_UPDATE_FIELDS) : {}
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
      
      # 检查路径格式和扩展名
      extension = File.extname(file_path).downcase[1..-1]
      file_path.match?(/\A\/.+\.(#{ALLOWED_FILE_EXTENSIONS.join('|')})\z/i) && ALLOWED_FILE_EXTENSIONS.include?(extension)
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