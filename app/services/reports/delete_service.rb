# app/services/reports/delete_report.rb
# 报告删除服务
# 处理健康报告软删除业务逻辑

module Reports
  class DeleteService
    # 服务对象的入口点
    # @param params [Hash] 删除参数，包含 report_id
    # @return [Hash] 标准化服务响应格式 { success: Boolean, data: Any, error: String/nil }
    def self.call(params = {})
      new(params).execute
    end

    # 初始化服务
    # @param params [Hash] 删除参数
    def initialize(params = {})
      @report_id = params[:report_id]
    end

    # 执行报告删除逻辑
    # @return [Hash] 标准化服务响应格式
    def execute
      # 验证报告ID
      return { success: false, data: nil, error: "报告ID不能为空" } if @report_id.blank?
      
      # 查找报告（包括已软删除的）
      report = Report.find_by(id: @report_id)
      return { success: false, data: nil, error: "报告不存在" } unless report
      
      # 如果报告已经被删除，返回成功（幂等操作）
      if report.deleted_at.present?
        Rails.logger.info "Reports::DeleteService - Report #{@report_id} already deleted, returning success (idempotent)"
        return {
          success: true,
          data: { 
            report_id: @report_id, 
            deleted_at: report.deleted_at,
            user_id: report.user_id,
            report_type: report.report_type,
            status: report.status
          },
          error: nil
        }
      end
      
      # 检查报告是否可以删除（只有最终结果可以删除）
      unless report.final_result?
        return { success: false, data: nil, error: "只有最终结果状态的报告才能删除" }
      end
      
      # 执行软删除
      if report.update(deleted_at: Time.current)
        delete_file_if_exists(report.file_path)
        Rails.logger.info "Reports::DeleteReport - Report #{@report_id} soft deleted successfully"
        {
          success: true,
          data: { 
            report_id: @report_id, 
            deleted_at: report.deleted_at,
            user_id: report.user_id,
            report_type: report.report_type,
            status: report.status
          },
          error: nil
        }
      else
        {
          success: false,
          data: nil,
          error: "删除失败: #{report.errors.full_messages.join(', ')}"
        }
      end
    rescue ActiveRecord::RecordNotFound
      { success: false, data: nil, error: "报告不存在" }
    rescue StandardError => e
      Rails.logger.error "Reports::DeleteReport error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, data: nil, error: "删除失败，请稍后重试" }
    end

    private

    # 删除物理文件（仅限受管目录）
    # @param file_path [String]
    def delete_file_if_exists(file_path)
      return if file_path.blank?
      value = file_path.to_s

      # 兼容旧的 public/uploads/reports 目录
      if value.start_with?("/uploads/reports/")
        absolute_path = Rails.root.join("public", value.delete_prefix("/"))
        File.delete(absolute_path) if File.exist?(absolute_path)
        return
      end

      # 新的 storage/reports 目录下的文件
      base_dir = Rails.application.config.x.reports_storage&.base_dir || Rails.root.join("storage", "reports")
      base = Pathname.new(base_dir)
      relative = Pathname.new(value)
      candidate = base.join(relative).cleanpath

      base_real = base.exist? ? base.realpath : base
      return unless candidate.to_s.start_with?(base_real.to_s)

      File.delete(candidate) if File.exist?(candidate)
    rescue StandardError => e
      Rails.logger.warn "Reports::DeleteService delete file warning: #{e.class} - #{e.message}"
    end
  end
end
