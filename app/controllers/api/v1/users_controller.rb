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
        # 记录请求参数用于调试
        Rails.logger.info "API Users Search - Request params: #{params.inspect}"
        
        # 调用用户搜索服务处理业务逻辑
        result = Users::SearchUsersService.call(service_params)
        
        if result[:success]
          # 成功时返回用户数据和分页信息，确保UTF-8编码
          render json: result[:data], status: :ok, content_type: 'application/json; charset=utf-8'
        else
          # 失败时返回错误信息，确保UTF-8编码
          render json: { error: result[:error] }, status: :unprocessable_entity, content_type: 'application/json; charset=utf-8'
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.error "API Users Search - Parameter error: #{e.message}"
        render json: { error: "参数错误: #{e.message}" }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "API Users Search - Unexpected error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error: "服务器内部错误" }, status: :internal_server_error
      end

      private

      # Strong Parameters定义
      # 定义允许的参数结构，确保数据安全性
      # @return [Hash] 允许的参数
      def service_params
        # 如果标准参数解析失败，尝试手动解析JSON
        if params.blank? || params.empty?
          begin
            raw_body = request.raw_post
            Rails.logger.info "Raw request body: #{raw_body}"
            
            if raw_body.present?
              parsed = JSON.parse(raw_body)
              return sanitize_params(parsed)
            end
          rescue JSON::ParserError => e
            Rails.logger.error "JSON parse error: #{e.message}"
          end
        end
        
        # 使用标准的参数解析
        sanitize_params(params.to_unsafe_h)
      end
      
      # 参数清洗
      def sanitize_params(param_hash)
        return {} unless param_hash.present?
        
        # 确保filters和pagination存在
        filters = param_hash[:filters] || param_hash["filters"] || {}
        pagination = param_hash[:pagination] || param_hash["pagination"] || {}
        
        # 转换字符串键为符号键
        filters = filters.transform_keys(&:to_sym) if filters.is_a?(Hash)
        pagination = pagination.transform_keys(&:to_sym) if pagination.is_a?(Hash)
        
        # 只保留允许的参数
        allowed_filters = filters.slice(:name, :email, :phone, :status, :role, :membership_type)
        allowed_pagination = pagination.slice(:page, :per_page)
        
        result = {
          filters: allowed_filters,
          pagination: allowed_pagination
        }
        
        Rails.logger.info "Sanitized params: #{result.inspect}"
        result
      rescue StandardError => e
        Rails.logger.error "Error in sanitize_params: #{e.message}"
        { filters: {}, pagination: {} }
      end
    end
  end
end