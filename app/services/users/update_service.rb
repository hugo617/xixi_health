# app/services/users/update_service.rb
# 用户更新服务
# 处理用户信息的更新业务逻辑

module Users
  class UpdateService
    # 允许更新的字段
    ALLOWED_UPDATE_FIELDS = %i[nickname email phone status role membership_type].freeze
    
    # 服务对象的入口点
    # @param params [Hash] 更新参数，包含 user_id 和需要更新的字段
    # @return [Hash] 标准化服务响应格式 { success: Boolean, data: Any, error: String/nil }
    def self.call(params = {})
      new(params).execute
    end

    # 初始化服务
    # @param params [Hash] 更新参数
    def initialize(params = {})
      @user_id = params[:user_id]
      user_params = params[:user] || {}
      @update_params = user_params.is_a?(Hash) ? user_params.symbolize_keys.slice(*ALLOWED_UPDATE_FIELDS) : {}
    end

    # 执行用户更新逻辑
    # @return [Hash] 标准化服务响应格式
    def execute
      # 验证用户ID
      return { success: false, data: nil, error: "用户ID不能为空" } if @user_id.blank?
      
      # 查找用户
      user = User.not_deleted.find_by(id: @user_id)
      return { success: false, data: nil, error: "用户不存在" } unless user
      
      # 验证更新参数
      return { success: false, data: nil, error: "没有提供有效的更新字段" } if @update_params.empty?
      
      # 更新用户信息
      if user.update(@update_params)
        {
          success: true,
          data: serialize_user(user),
          error: nil
        }
      else
        {
          success: false,
          data: nil,
          error: user.errors.full_messages.join(", ")
        }
      end
    rescue ActiveRecord::RecordNotFound
      { success: false, data: nil, error: "用户不存在" }
    rescue ActiveRecord::RecordInvalid => e
      { success: false, data: nil, error: e.record.errors.full_messages.join(", ") }
    rescue StandardError => e
      Rails.logger.error "Users::UpdateService error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, data: nil, error: "更新失败，请稍后重试" }
    end

    private

    # 序列化用户数据
    # @param user [User] 用户对象
    # @return [Hash] 序列化后的用户数据
    def serialize_user(user)
      user.as_json(
        only: [:id, :nickname, :email, :phone, :role, :status, :membership_type, :created_at, :updated_at],
        methods: [:active?, :admin?, :valid_member?]
      )
    end
  end
end