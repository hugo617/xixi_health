# app/services/users/search_users_service.rb
# 用户搜索服务
# 处理用户查询的业务逻辑，包括筛选、分页等功能

class Users::SearchUsersService
  # 服务对象的入口点
  # @param params [Hash] 查询参数
  # @return [Hash] 标准化服务响应格式 { success: Boolean, data: Any, error: String/nil }
  def self.call(params = {})
    new(params).execute
  end

  # 初始化服务
  # @param params [Hash] 查询参数
  def initialize(params = {})
    @params = params
    @filters = params[:filters] || {}
    @pagination = params[:pagination] || {}
    
    # 记录参数用于调试
    Rails.logger.info "SearchUsersService initialized with params: #{params.inspect}"
    Rails.logger.info "Filters: #{@filters.inspect}"
    Rails.logger.info "Pagination: #{@pagination.inspect}"
  end

  # 执行用户搜索逻辑
  # @return [Hash] 标准化服务响应格式
  def execute
    # 构建查询
    users = build_query
    
    # 应用分页
    paginated_users = apply_pagination(users)
    
    # 构建响应数据
    data = {
      users: serialize_users(paginated_users),
      pagination: {
        current_page: current_page,
        per_page: per_page,
        total_count: users.count,
        total_pages: total_pages(users.count)
      }
    }
    
    { success: true, data: data, error: nil }
    
  rescue StandardError => e
    { success: false, data: nil, error: e.message }
  end

  private

  # 构建查询条件
  # @return [ActiveRecord::Relation] 用户查询关系
  def build_query
    query = User.all
    
    # 应用筛选条件
    query = apply_name_filter(query)
    query = apply_email_filter(query)
    query = apply_status_filter(query)
    query = apply_role_filter(query)
    query = apply_membership_type_filter(query)
    query = apply_phone_filter(query)
    
    # 默认排除已删除的用户
    query.where(deleted_at: nil)
  end

  # @return [ActiveRecord::Relation] 应用姓名、邮箱、状态、角色、会员类型、手机号的筛选后的查询关系
  
  # 应用姓名筛选
  def apply_name_filter(query)
    return query unless @filters[:name].present?
    query.search_by_nickname(@filters[:name])
  end

  # 应用邮箱筛选
  def apply_email_filter(query)
    return query unless @filters[:email].present?
    query.search_by_email(@filters[:email])
  end

  # 应用状态筛选
  def apply_status_filter(query)
    return query unless @filters[:status].present?
    query.where(status: @filters[:status])
  end

  # 应用角色筛选
  def apply_role_filter(query)
    return query unless @filters[:role].present?
    query.where(role: @filters[:role])
  end

  # 应用会员类型筛选
  def apply_membership_type_filter(query)
    return query unless @filters[:membership_type].present?
    query.where(membership_type: @filters[:membership_type])
  end

  # 应用手机号筛选
  def apply_phone_filter(query)
    return query unless @filters[:phone].present?
    query.search_by_phone(@filters[:phone])
  end

  # 应用分页
  # @param query [ActiveRecord::Relation] 查询关系
  # @return [ActiveRecord::Relation] 分页后的查询关系
  def apply_pagination(query)
    query.page(current_page).per(per_page)
  end

  # 获取当前页码
  # @return [Integer] 当前页码
  def current_page
    @pagination[:page]&.to_i || 1
  end

  # 获取每页记录数
  # @return [Integer] 每页记录数
  def per_page
    @pagination[:per_page]&.to_i || 20
  end

  # 计算总页数
  # @param total_count [Integer] 总记录数
  # @return [Integer] 总页数
  def total_pages(total_count)
    (total_count.to_f / per_page).ceil
  end

  # 序列化用户数据
  # @param users [ActiveRecord::Relation] 用户查询关系
  # @return [Array<Hash>] 序列化后的用户数据
  def serialize_users(users)
    users.map do |user|
      user.as_json(
        only: [:id, :nickname, :email, :phone, :role, :status, :membership_type, :created_at, :updated_at],
        methods: [:active?, :admin?, :valid_member?]
      )
    end
  end
end