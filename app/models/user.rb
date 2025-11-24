class User < ApplicationRecord
  # 密码加密
  has_secure_password
  
  # 枚举定义
  enum :membership_type, {
    session_card: 'session_card',    # 次卡
    monthly_card: 'monthly_card',    # 月卡
    annual_card: 'annual_card',      # 年卡
    no_membership: 'no_membership'   # 无（避免与ActiveRecord的none方法冲突）
  }, default: 'no_membership'
  
  enum :role, {
    user: 'user',                    # 普通用户
    admin: 'admin'                   # 超级管理员
  }, default: 'user'
  
  enum :status, {
    active: 'active',                # 活跃
    inactive: 'inactive'             # 停用
  }, default: 'active'
  
  # 关联关系
  # has_many :health_reports, dependent: :destroy
  
  # 验证规则
  validates :nickname, presence: true, length: { minimum: 2, maximum: 50 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true, uniqueness: true
  validates :membership_type, inclusion: { in: %w[session_card monthly_card annual_card no_membership] }
  validates :role, inclusion: { in: %w[user admin] }
  validates :status, inclusion: { in: %w[active inactive] }
  
  # 作用域
  scope :active, -> { where(status: 'active') }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :admins, -> { where(role: 'admin') }
  scope :regular_users, -> { where(role: 'user') }
  scope :with_membership, -> { where.not(membership_type: 'no_membership') }
  
  # 搜索作用域
  scope :search_by_nickname, ->(keyword) { 
    where('nickname LIKE ?', "%#{keyword}%") if keyword.present?
  }
  scope :search_by_email, ->(email) { 
    where('email LIKE ?', "%#{email}%") if email.present?
  }
  scope :search_by_phone, ->(phone) { 
    where('phone LIKE ?', "%#{phone}%") if phone.present?
  }
  
  # 实例方法
  def active?
    status == 'active' && deleted_at.nil?
  end
  
  def admin?
    role == 'admin'
  end
  
  def valid_member?
    membership_type != 'no_membership'
  end
  
  def has_membership?
    membership_type != 'no_membership'
  end
  
  # 类方法
  def self.create_with_defaults(attributes)
    new(attributes.reverse_merge(
      role: 'user',
      status: 'active',
      membership_type: 'no_membership'
    ))
  end
  
  # 序列化
  def as_json(options = {})
    super(options.merge(
      except: [:password_digest],
      methods: [:active?, :admin?, :valid_member?]
    ))
  end
  
  private
  
  def set_default_values
    self.status ||= 'active'
    self.role ||= 'user'
    self.membership_type ||= 'no_membership'
  end
  
  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end