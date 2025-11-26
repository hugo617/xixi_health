class Report < ApplicationRecord
  # 关联关系
  belongs_to :user
  
  # 枚举定义
  enum :report_type, {
    protein_test: 'protein_test',      # 蛋白质检测报告
    gene_test: 'gene_test',            # 基因检测报告
    blood_test: 'blood_test',          # 血液检测报告
    urine_test: 'urine_test',          # 尿液检测报告
    other_test: 'other_test'           # 其他检测
  }, default: 'other_test'
  
  enum :status, {
    pending_generation: 'pending_generation',    # 待生成
    under_review: 'under_review',                # 审核中
    normal_result: 'normal_result',              # 结果正常类
    abnormal_mild: 'abnormal_mild',              # 结果异常类（轻度）
    abnormal_moderate: 'abnormal_moderate',      # 结果异常类（中度）
    abnormal_severe: 'abnormal_severe',          # 结果异常类（重度）
    pending_supplement: 'pending_supplement',    # 特殊类（待补充）
    pending_revision: 'pending_revision'         # 特殊类（待修订）
  }, default: 'pending_generation'
  
  # 验证规则
  validates :user_id, presence: true
  validates :report_type, presence: true, inclusion: { in: %w[protein_test gene_test blood_test urine_test other_test] }
  validates :file_path, presence: true
  validates :status, inclusion: { in: %w[pending_generation under_review normal_result abnormal_mild abnormal_moderate abnormal_severe pending_supplement pending_revision] }
  validates :file_size, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  
  # 自定义验证
  validate :report_date_cannot_be_in_the_future
  validate :file_size_reasonable
  
  # 作用域
  scope :active, -> { where(deleted_at: nil) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  
  # 状态作用域 - 进度类
  scope :pending_generation, -> { where(status: 'pending_generation') }
  scope :under_review, -> { where(status: 'under_review') }
  
  # 状态作用域 - 结果正常类
  scope :normal_result, -> { where(status: 'normal_result') }
  
  # 状态作用域 - 结果异常类
  scope :abnormal_results, -> { where(status: %w[abnormal_mild abnormal_moderate abnormal_severe]) }
  scope :abnormal_mild, -> { where(status: 'abnormal_mild') }
  scope :abnormal_moderate, -> { where(status: 'abnormal_moderate') }
  scope :abnormal_severe, -> { where(status: 'abnormal_severe') }
  
  # 状态作用域 - 特殊类
  scope :pending_supplement, -> { where(status: 'pending_supplement') }
  scope :pending_revision, -> { where(status: 'pending_revision') }
  scope :special_status, -> { where(status: %w[pending_supplement pending_revision]) }
  
  # 组合状态作用域
  scope :in_progress, -> { where(status: %w[pending_generation under_review]) }
  scope :final_result, -> { where(status: %w[normal_result abnormal_mild abnormal_moderate abnormal_severe]) }
  
  # 报告类型作用域
  scope :protein_tests, -> { where(report_type: 'protein_test') }
  scope :gene_tests, -> { where(report_type: 'gene_test') }
  scope :blood_tests, -> { where(report_type: 'blood_test') }
  scope :urine_tests, -> { where(report_type: 'urine_test') }
  
  # 时间范围作用域
  scope :recent, -> { where('created_at >= ?', 1.week.ago) }
  scope :by_date_range, ->(start_date, end_date) { 
    where(report_date: start_date.beginning_of_day..end_date.end_of_day) 
  }
  
  # 文件大小作用域
  scope :large_files, -> { where('file_size > ?', 10.megabytes) }
  scope :small_files, -> { where('file_size <= ?', 1.megabyte) }
  
  # 搜索作用域
  scope :search_by_type, ->(type) { 
    where(report_type: type) if type.present? 
  }
  scope :search_by_status, ->(status) { 
    where(status: status) if status.present? 
  }
  
  # 实例方法
  def active?
    deleted_at.nil?
  end
  
  def deleted?
    deleted_at.present?
  end
  
  def pending_generation?
    status == 'pending_generation'
  end

  def under_review?
    status == 'under_review'
  end

  def normal_result?
    status == 'normal_result'
  end

  def abnormal?
    %w[abnormal_mild abnormal_moderate abnormal_severe].include?(status)
  end

  def abnormal_mild?
    status == 'abnormal_mild'
  end

  def abnormal_moderate?
    status == 'abnormal_moderate'
  end

  def abnormal_severe?
    status == 'abnormal_severe'
  end

  def pending_supplement?
    status == 'pending_supplement'
  end

  def pending_revision?
    status == 'pending_revision'
  end

  def special_status?
    %w[pending_supplement pending_revision].include?(status)
  end

  def in_progress?
    %w[pending_generation under_review].include?(status)
  end

  def final_result?
    %w[normal_result abnormal_mild abnormal_moderate abnormal_severe].include?(status)
  end
  
  # 文件大小格式化显示
  def formatted_file_size
    return '未知' if file_size.nil?
    
    if file_size < 1024
      "#{file_size} B"
    elsif file_size < 1024 * 1024
      "#{(file_size / 1024.0).round(2)} KB"
    elsif file_size < 1024 * 1024 * 1024
      "#{(file_size / (1024.0 * 1024)).round(2)} MB"
    else
      "#{(file_size / (1024.0 * 1024 * 1024)).round(2)} GB"
    end
  end
  
  # 报告年龄（从生成日期开始）
  def report_age_in_days
    return nil if report_date.nil?
    (Date.current - report_date.to_date).to_i
  end
  
  # 是否可以删除（软删除）
  def can_be_deleted?
    !deleted? && final_result?
  end
  
  # 软删除方法
  def soft_delete
    update(deleted_at: Time.current) if can_be_deleted?
  end
  
  # 恢复软删除
  def restore
    update(deleted_at: nil) if deleted?
  end
  
  # 序列化配置
  def as_json(options = {})
    super(options.merge(
      except: [:deleted_at],
      methods: [:active?, :normal_result?, :abnormal?, :abnormal_mild?, :abnormal_moderate?, :abnormal_severe?, :in_progress?, :final_result?, :formatted_file_size, :report_age_in_days],
      include: {
        user: { only: [:id, :nickname, :email] }
      }
    ))
  end
  
  private
  
  # 验证报告日期不能是未来日期
  def report_date_cannot_be_in_the_future
    return if report_date.nil?
    
    if report_date > Time.current
      errors.add(:report_date, "不能是未来日期")
    end
  end
  
  # 验证文件大小合理性
  def file_size_reasonable
    return if file_size.nil?
    
    if file_size < 0
      errors.add(:file_size, "不能为负数")
    elsif file_size > 100.megabytes
      errors.add(:file_size, "不能超过100MB")
    end
  end
end