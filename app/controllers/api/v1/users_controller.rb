# app/controllers/api/v1/users_controller.rb
# API用户控制器
# 处理用户相关的API请求，遵循瘦控制器原则

module Api
  module V1
    class UsersController < BaseController
      # POST /api/v1/users/search
      # 用户搜索接口
      # 支持按多种条件筛选用户并分页返回结果
      def search
        result = Users::SearchService.call(search_params)
        
        if result[:success]
          render_success(result[:data])
        else
          render_error(result[:error])
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.error "API Users Search - Parameter error: #{e.message}"
        render_error("参数错误: #{e.message}", :bad_request)
      rescue StandardError => e
        Rails.logger.error "API Users Search - Unexpected error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render_error("服务器内部错误", :internal_server_error)
      end

      private

      # Strong Parameters定义
      # 使用Rails标准的参数解析，支持JSON和表单数据
      # @return [Hash] 允许的参数
      def search_params
        params.permit(
          filters: [:name, :email, :phone, :status, :role, :membership_type],
          pagination: [:page, :per_page]
        ).to_h.symbolize_keys
      end
    end
  end
end