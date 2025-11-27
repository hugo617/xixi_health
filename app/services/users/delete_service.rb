# app/services/users/delete_service.rb
# 用户删除服务
# 处理用户软删除业务逻辑

module Users
  class DeleteService
    # 服务对象的入口点
    # @param params [Hash] 删除参数，包含 user_id
    # @return [Hash] 标准化服务响应格式 { success: Boolean, data: Any, error: String/nil }
    def self.call(params = {})
      new(params).execute
    end

    # 初始化服务
    # @param params [Hash] 删除参数
    def initialize(params = {})
      @user_id = params[:user_id]
    end

    # 执行用户删除逻辑
    # @return [Hash] 标准化服务响应格式
    def execute
      # 验证用户ID
      return { success: false, data: nil, error: "用户ID不能为空" } if @user_id.blank?
      
      # 查找用户（包括已软删除的）
      user = User.find_by(id: @user_id)
      return { success: false, data: nil, error: "用户不存在" } unless user
      
      # 如果用户已经被删除，返回成功（幂等操作）
      if user.deleted_at.present?
        Rails.logger.info "Users::DeleteService - User #{@user_id} already deleted, returning success (idempotent)"
        return {
          success: true,
          data: { user_id: @user_id, deleted_at: user.deleted_at },
          error: nil
        }
      end
      
      # 执行软删除
      if user.update(deleted_at: Time.current)
        Rails.logger.info "Users::DeleteService - User #{@user_id} soft deleted successfully"
        {
          success: true,
          data: { user_id: @user_id, deleted_at: user.deleted_at },
          error: nil
        }
      else
        {
          success: false,
          data: nil,
          error: "删除失败: #{user.errors.full_messages.join(', ')}"
        }
      end
    rescue ActiveRecord::RecordNotFound
      { success: false, data: nil, error: "用户不存在" }
    rescue StandardError => e
      Rails.logger.error "Users::DeleteService error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, data: nil, error: "删除失败，请稍后重试" }
    end
  end
end