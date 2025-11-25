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

      # POST /api/v1/users/update
      # 用户更新接口
      # 更新用户信息
      def update
        result = Users::UpdateService.call(update_params)
        
        if result[:success]
          render_success(result[:data])
        else
          render_error(result[:error])
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.error "API Users Update - Parameter error: #{e.message}"
        render_error("参数错误: #{e.message}", :bad_request)
      rescue StandardError => e
        Rails.logger.error "API Users Update - Unexpected error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render_error("服务器内部错误", :internal_server_error)
      end

      # POST /api/v1/users/delete
      # 用户删除接口
      # 软删除用户
      def delete
        result = Users::DeleteService.call(delete_params)
        
        if result[:success]
          render_success(result[:data])
        else
          render_error(result[:error])
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.error "API Users Delete - Parameter error: #{e.message}"
        render_error("参数错误: #{e.message}", :bad_request)
      rescue StandardError => e
        Rails.logger.error "API Users Delete - Unexpected error: #{e.class} - #{e.message}"
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

      # 用户更新参数
      # @return [Hash] 允许的更新参数
      def update_params
        {
          user_id: params[:user_id],
          user: params[:user]&.permit(:nickname, :email, :phone, :status, :role, :membership_type)&.to_h
        }.compact
      end

      # 用户删除参数
      # @return [Hash] 允许的删除参数
      def delete_params
        params.permit(:user_id).to_h
      end
    end
  end
end