# app/controllers/api/v1/base_controller.rb
# API基础控制器
# 所有API控制器都应该继承此控制器，统一管理API相关的行为

module Api
  module V1
    class BaseController < ApplicationController
      # API接口跳过CSRF验证
      # API通常使用token认证或其他认证方式，不需要CSRF保护
      skip_forgery_protection
      
      # 确保响应使用UTF-8编码
      before_action :set_utf8_encoding
      
      private
      
      # 设置UTF-8编码
      def set_utf8_encoding
        response.headers['Content-Type'] = 'application/json; charset=utf-8'
      end
      
      # 统一API响应格式
      # 成功响应
      def render_success(data = {}, status = :ok)
        render json: { success: true, data: data, error: nil }, status: status
      end
      
      # 错误响应
      def render_error(error_message, status = :unprocessable_entity)
        render json: { success: false, data: nil, error: error_message }, status: status
      end
      
      # 未授权响应
      def render_unauthorized(error_message = "未授权访问")
        render json: { success: false, data: nil, error: error_message }, status: :unauthorized
      end
      
      # 未找到资源响应
      def render_not_found(error_message = "资源未找到")
        render json: { success: false, data: nil, error: error_message }, status: :not_found
      end
    end
  end
end