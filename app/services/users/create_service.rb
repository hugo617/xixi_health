# app/services/users/create_service.rb
# 用户创建服务
# 处理新用户创建的业务逻辑

module Users
  class CreateService
    # 允许创建的字段
    ALLOWED_CREATE_FIELDS = %i[nickname email phone password password_confirmation status role membership_type].freeze
    
    # 默认密码长度
    MIN_PASSWORD_LENGTH = 6
    MAX_PASSWORD_LENGTH = 128
    
    # 服务对象的入口点
    # @param params [Hash] 创建参数
    # @return [Hash] 标准化服务响应格式 { success: Boolean, data: Any, error: String/nil }
    def self.call(params = {})
      new(params).execute
    end

    # 初始化服务
    # @param params [Hash] 创建参数
    def initialize(params = {})
      @create_params = (params[:user] || {}).symbolize_keys.slice(*ALLOWED_CREATE_FIELDS)
      # 设置默认值
      @create_params[:status] ||= 'active'
      @create_params[:role] ||= 'user'
      @create_params[:membership_type] ||= 'no_membership'
    end

    # 执行用户创建逻辑
    # @return [Hash] 标准化服务响应格式
    def execute
      # 验证创建参数
      validation_result = validate_create_params
      return validation_result unless validation_result[:success]
      
      # 创建用户
      user = User.new(@create_params)
      
      if user.save
        Rails.logger.info "Users::CreateService - User created successfully: ID #{user.id}, Email: #{user.email}"
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
    rescue ActiveRecord::RecordInvalid => e
      { success: false, data: nil, error: e.record.errors.full_messages.join(", ") }
    rescue StandardError => e
      Rails.logger.error "Users::CreateService error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, data: nil, error: "创建用户失败，请稍后重试" }
    end

    private

    # 验证创建参数
    # @return [Hash] 验证结果
    def validate_create_params
      # 检查必需字段
      required_fields = [:nickname, :email, :phone, :password]
      missing_fields = required_fields.select { |field| @create_params[field].blank? }
      
      if missing_fields.any?
        field_names = {
          nickname: "用户名",
          email: "邮箱",
          phone: "手机号",
          password: "密码"
        }
        missing_names = missing_fields.map { |f| field_names[f] }.join("、")
        return { success: false, data: nil, error: "缺少必需字段: #{missing_names}" }
      end
      
      # 验证邮箱格式
      unless @create_params[:email].match?(URI::MailTo::EMAIL_REGEXP)
        return { success: false, data: nil, error: "邮箱格式不正确" }
      end
      
      # 验证密码长度
      password_length = @create_params[:password].length
      if password_length < MIN_PASSWORD_LENGTH
        return { success: false, data: nil, error: "密码长度不能少于#{MIN_PASSWORD_LENGTH}位" }
      end
      
      if password_length > MAX_PASSWORD_LENGTH
        return { success: false, data: nil, error: "密码长度不能超过#{MAX_PASSWORD_LENGTH}位" }
      end
      
      # 验证密码确认
      if @create_params[:password_confirmation].present? && @create_params[:password] != @create_params[:password_confirmation]
        return { success: false, data: nil, error: "密码确认不匹配" }
      end
      
      # 验证用户名长度
      nickname_length = @create_params[:nickname].length
      if nickname_length < 2 || nickname_length > 50
        return { success: false, data: nil, error: "用户名长度必须在2-50个字符之间" }
      end
      
      # 验证手机号格式（中国手机号）
      unless @create_params[:phone].match?(/\A1[3-9]\d{9}\z/)
        return { success: false, data: nil, error: "手机号格式不正确" }
      end
      
      # 检查邮箱和手机号是否已存在
      if User.exists?(email: @create_params[:email])
        return { success: false, data: nil, error: "邮箱已被使用" }
      end
      
      if User.exists?(phone: @create_params[:phone])
        return { success: false, data: nil, error: "手机号已被使用" }
      end
      
      { success: true, data: nil, error: nil }
    end

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