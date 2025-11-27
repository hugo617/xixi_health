# app/controllers/api/v1/reports_controller.rb
# API报告控制器
# 处理健康报告相关的API请求，遵循瘦控制器原则

module Api
  module V1
    class ReportsController < BaseController
      # POST /api/v1/reports/search
      # 报告搜索接口
      # 支持按多种条件筛选报告并分页返回结果
      def search
        result = Reports::SearchService.call(search_params)
        
        if result[:success]
          render_success(result[:data])
        else
          render_error(result[:error])
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.error "API Reports Search - Parameter error: #{e.message}"
        render_error("参数错误: #{e.message}", :bad_request)
      rescue StandardError => e
        Rails.logger.error "API Reports Search - Unexpected error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render_error("服务器内部错误", :internal_server_error)
      end

      # POST /api/v1/reports/create
      # 报告创建接口
      # 创建新的健康报告
      def create
        result = Reports::CreateService.call(create_params)
        
        if result[:success]
          render_success(result[:data])
        else
          render_error(result[:error])
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.error "API Reports Create - Parameter error: #{e.message}"
        render_error("参数错误: #{e.message}", :bad_request)
      rescue StandardError => e
        Rails.logger.error "API Reports Create - Unexpected error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render_error("服务器内部错误", :internal_server_error)
      end

      # POST /api/v1/reports/update
      # 报告更新接口
      # 更新现有健康报告信息
      def update
        result = Reports::UpdateService.call(update_params)
        
        if result[:success]
          render_success(result[:data])
        else
          render_error(result[:error])
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.error "API Reports Update - Parameter error: #{e.message}"
        render_error("参数错误: #{e.message}", :bad_request)
      rescue StandardError => e
        Rails.logger.error "API Reports Update - Unexpected error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render_error("服务器内部错误", :internal_server_error)
      end

      # POST /api/v1/reports/delete
      # 报告删除接口
      # 软删除健康报告（只有最终结果状态的报告可以删除）
      def delete
        result = Reports::DeleteService.call(delete_params)
        
        if result[:success]
          render_success(result[:data])
        else
          render_error(result[:error])
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.error "API Reports Delete - Parameter error: #{e.message}"
        render_error("参数错误: #{e.message}", :bad_request)
      rescue StandardError => e
        Rails.logger.error "API Reports Delete - Unexpected error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render_error("服务器内部错误", :internal_server_error)
      end

      private

      # Strong Parameters定义
      # 使用Rails标准的参数解析，支持JSON和表单数据
      # @return [Hash] 允许的参数
      def search_params
        params.permit(
          filters: [:user_id, :report_type, :status, :start_date, :end_date, :abnormal_only, :special_status],
          pagination: [:page, :per_page]
        ).to_h.symbolize_keys
      end

      # 创建参数定义
      # @return [Hash] 允许的创建参数
      def create_params
        params.permit(report: [:user_id, :report_type, :status, :file_path, :report_date, :file_size, :description]).to_h
      end

      # 更新参数定义
      # @return [Hash] 允许的更新参数
      def update_params
        {
          report_id: params[:report_id],
          report: params[:report]&.permit(:report_type, :status, :file_path, :report_date, :file_size, :description)&.to_h
        }.compact
      end

      # 删除参数定义
      # @return [Hash] 允许的删除参数
      def delete_params
        params.permit(:report_id).to_h
      end
    end
  end
end