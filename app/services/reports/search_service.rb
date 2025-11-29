# app/services/reports/search_service.rb
# 报告搜索服务
# 处理健康报告查询的业务逻辑，包括筛选、分页等功能

module Reports
  class SearchService
    # 每页最大记录数限制
    MAX_PER_PAGE = 100
    DEFAULT_PER_PAGE = 20
    
    # 允许的筛选字段
    ALLOWED_FILTERS = %i[user_id report_type status start_date end_date abnormal_only special_status].freeze
    
    # 服务对象的入口点
    # @param params [Hash] 查询参数，包含 filters 和 pagination
    # @return [Hash] 标准化服务响应格式 { success: Boolean, data: Any, error: String/nil }
    def self.call(params = {})
      new(params).execute
    end

    # 初始化服务
    # @param params [Hash] 查询参数
    def initialize(params = {})
      @filters = (params[:filters] || {}).symbolize_keys.slice(*ALLOWED_FILTERS)
      @pagination = (params[:pagination] || {}).symbolize_keys.slice(:page, :per_page)
    end

    # 执行报告搜索逻辑
    # @return [Hash] 标准化服务响应格式
    def execute
      query = build_query
      paginated_result = apply_pagination(query)
      
      {
        success: true,
        data: {
          reports: serialize_reports(paginated_result),
          pagination: build_pagination_meta(paginated_result)
        },
        error: nil
      }
    rescue StandardError => e
      Rails.logger.error "Reports::SearchService error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, data: nil, error: "查询失败，请稍后重试" }
    end

    private

    # 构建查询条件
    # @return [ActiveRecord::Relation] 报告查询关系
    def build_query
      query = Report.active.includes(:user)
      
      # 应用筛选条件
      @filters.each do |key, value|
        next unless value.present?
        query = apply_filter(query, key, value)
      end
      
      # 默认按创建时间倒序
      query.order(created_at: :desc)
    end

    # 应用单个筛选条件
    # @param query [ActiveRecord::Relation] 查询关系
    # @param key [Symbol] 筛选字段名
    # @param value [String, Integer, Boolean] 筛选值
    # @return [ActiveRecord::Relation] 应用筛选后的查询关系
    def apply_filter(query, key, value)
      case key
      when :user_id
        query.where(user_id: value)
      when :report_type
        query.where(report_type: value)
      when :status
        query.where(status: value)
      when :start_date
        query.where('report_date >= ?', Date.parse(value.to_s).beginning_of_day)
      when :end_date
        query.where('report_date <= ?', Date.parse(value.to_s).end_of_day)
      when :abnormal_only
        query.abnormal_results if value.to_s == 'true'
      when :special_status
        query.special_status if value.to_s == 'true'
      else
        query
      end
    rescue ArgumentError => e
      Rails.logger.warn "Reports::SearchService - Invalid date format for #{key}: #{value}"
      query # 如果日期格式无效，跳过此筛选条件
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
      page = @pagination[:page]&.to_i
      page&.positive? ? page : 1
    end

    # 获取每页记录数
    # @return [Integer] 每页记录数
    def per_page
      per_page_value = @pagination[:per_page]&.to_i
      return DEFAULT_PER_PAGE unless per_page_value&.positive?
      [per_page_value, MAX_PER_PAGE].min
    end

    # 构建分页元数据
    # @param paginated_result [ActiveRecord::Relation] 分页后的查询结果
    # @return [Hash] 分页元数据
    def build_pagination_meta(paginated_result)
      {
        current_page: paginated_result.current_page,
        per_page: paginated_result.limit_value,
        total_count: paginated_result.total_count,
        total_pages: paginated_result.total_pages
      }
    end

    # 序列化报告数据
    # @param reports [ActiveRecord::Relation] 报告查询关系
    # @return [Array<Hash>] 序列化后的报告数据
    def serialize_reports(reports)
      reports.map do |report|
        report.as_json(
          only: [:id, :user_id, :report_type, :status, :file_path, :report_date,
                 :file_size, :description, :original_filename, :created_at, :updated_at],
          methods: [:active?, :normal_result?, :abnormal?, :abnormal_mild?, 
                   :abnormal_moderate?, :abnormal_severe?, :in_progress?, 
                   :final_result?, :formatted_file_size, :report_age_in_days],
          include: {
            user: { only: [:id, :nickname, :email] }
          }
        )
      end
    end
  end
end
