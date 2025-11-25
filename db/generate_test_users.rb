#!/usr/bin/env ruby

# 生成50个测试用户数据的脚本
require 'securerandom'

# 用户数据配置
NICKNAMES = [
  "熊猫用户", "绿色森林", "科技达人", "健康守护者", "数据分析师",
  "产品经理", "设计师", "开发工程师", "测试工程师", "运维工程师",
  "市场专员", "销售代表", "客服专员", "财务专员", "人事专员",
  "行政助理", "法务专员", "采购专员", "质量管理员", "项目管理员",
  "系统管理员", "数据库管理员", "网络管理员", "安全管理员", "文档管理员",
  "培训讲师", "咨询顾问", "技术支持", "客户服务", "业务代表",
  "区域经理", "销售经理", "市场经理", "产品经理", "运营经理",
  "财务经理", "人事经理", "行政经理", "法务经理", "技术经理",
  "研发经理", "测试经理", "运维经理", "项目经理", "质量经理",
  "数据分析师", "业务分析师", "系统分析师", "网络架构师", "解决方案架构师"
]

EMAIL_DOMAINS = [
  "myshell.ai", "healthtech.com", "datacare.net", "wellness.cloud", "medical.io",
  "company.com", "enterprise.net", "corporate.org", "business.io", "consulting.com",
  "gmail.com", "outlook.com", "yahoo.com", "qq.com", "163.com"
]

MEMBERSHIP_TYPES = ["no_membership", "session_card", "monthly_card", "annual_card"]
ROLES = ["user", "admin"]
STATUSES = ["active", "inactive"]

PHONE_PREFIXES = ["138", "139", "136", "137", "150", "151", "152", "158", "159", "188", "189", "187", "186"]

def generate_phone
  prefix = PHONE_PREFIXES.sample
  suffix = rand(10000000..99999999).to_s
  prefix + suffix
end

def generate_email(nickname)
  # 创建拼音风格的用户名
  username = nickname.gsub(/[^\w]/, '').downcase[0..10]
  username += rand(100..999).to_s if rand > 0.5
  domain = EMAIL_DOMAINS.sample
  "#{username}@#{domain}"
end

def generate_nickname(index)
  # 循环使用昵称池，添加序号避免重复
  base_nickname = NICKNAMES[index % NICKNAMES.length]
  if rand > 0.7
    "#{base_nickname}#{rand(1..99)}"
  else
    base_nickname
  end
end

def generate_user(index)
  nickname = generate_nickname(index)
  
  {
    nickname: nickname,
    email: generate_email(nickname),
    phone: generate_phone,
    password: "password123", # 默认密码
    password_confirmation: "password123",
    membership_type: MEMBERSHIP_TYPES.sample,
    role: ROLES.sample,
    status: STATUSES.sample,
    created_at: Time.now - rand(0..365).days,
    updated_at: Time.now - rand(0..30).days
  }
end

def create_test_users
  puts "=" * 60
  puts "🎯 开始生成50个测试用户"
  puts "=" * 60
  puts ""
  
  success_count = 0
  failed_count = 0
  failed_users = []
  
  # 先生成所有用户数据
  users_data = []
  50.times do |i|
    users_data << generate_user(i)
  end
  
  puts "📊 生成了 #{users_data.length} 个用户数据模板"
  puts ""
  
  # 显示前5个用户作为示例
  puts "📋 前5个用户示例："
  users_data.first(5).each_with_index do |user, index|
    puts "  #{index + 1}. #{user[:nickname]}"
    puts "     📧 #{user[:email]}"
    puts "     📱 #{user[:phone]}"
    puts "     🏷️  #{user[:membership_type]} | #{user[:role]} | #{user[:status]}"
    puts ""
  end
  
  puts "🚀 开始创建用户记录..."
  puts ""
  
  # 使用ActiveRecord创建用户
  users_data.each_with_index do |user_data, index|
    begin
      user = User.new(user_data)
      if user.save
        success_count += 1
        print "✅ 用户 #{index + 1}/50 创建成功: #{user.nickname}\r"
        STDOUT.flush
      else
        failed_count += 1
        failed_users << {
          index: index + 1,
          data: user_data,
          errors: user.errors.full_messages
        }
        puts "❌ 用户 #{index + 1}/50 创建失败: #{user.errors.full_messages.join(', ')}"
      end
    rescue => e
      failed_count += 1
      failed_users << {
        index: index + 1,
        data: user_data,
        errors: [e.message]
      }
      puts "❌ 用户 #{index + 1}/50 创建异常: #{e.message}"
    end
  end
  
  puts ""
  puts ""
  
  # 显示统计结果
  puts "=" * 60
  puts "📊 用户创建统计"
  puts "=" * 60
  puts ""
  puts "✅ 成功创建: #{success_count} 个用户"
  puts "❌ 创建失败: #{failed_count} 个用户"
  puts "📈 成功率: #{(success_count.to_f / 50 * 100).round(1)}%"
  puts ""
  
  # 显示失败详情
  if failed_users.any?
    puts "=" * 60
    puts "❌ 失败用户详情"
    puts "=" * 60
    puts ""
    failed_users.first(5).each do |failed|
      puts "  用户 ##{failed[:index]}:"
      puts "    昵称: #{failed[:data][:nickname]}"
      puts "    错误: #{failed[:errors].join('; ')}"
      puts ""
    end
    
    if failed_users.length > 5
      puts "  ... 还有 #{failed_users.length - 5} 个失败记录"
      puts ""
    end
  end
  
  # 显示最终数据库状态
  puts "=" * 60
  puts "📈 数据库状态"
  puts "=" * 60
  puts ""
  
  total_users = User.count
  active_users = User.where(status: 'active').count
  admin_users = User.where(role: 'admin').count
  
  puts "👥 总用户数: #{total_users}"
  puts "✅ 活跃用户数: #{active_users}"
  puts "👑 管理员数: #{admin_users}"
  puts ""
  
  # 显示用户分布统计
  membership_stats = User.group(:membership_type).count
  role_stats = User.group(:role).count
  status_stats = User.group(:status).count
  
  puts "🏷️ 会员类型分布："
  membership_stats.each do |type, count|
    puts "  • #{type}: #{count} 人"
  end
  puts ""
  
  puts "👥 角色分布："
  role_stats.each do |role, count|
    puts "  • #{role}: #{count} 人"
  end
  puts ""
  
  puts "🚦 状态分布："
  status_stats.each do |status, count|
    puts "  • #{status}: #{count} 人"
  end
  puts ""
  
  # 显示最近创建的5个用户
  recent_users = User.order(created_at: :desc).limit(5)
  puts "🕐 最近创建的5个用户："
  recent_users.each_with_index do |user, index|
    puts "  #{index + 1}. #{user.nickname} (#{user.created_at.strftime('%Y-%m-%d %H:%M')})"
  end
  puts ""
  
  puts "=" * 60
  puts "✅ 测试用户生成完成！"
  puts "=" * 60
  
  return {
    success_count: success_count,
    failed_count: failed_count,
    total_users: total_users,
    membership_stats: membership_stats,
    role_stats: role_stats,
    status_stats: status_stats
  }
end

# 如果直接运行此脚本
if __FILE__ == $0
  # 确保Rails环境加载
  require_relative '../config/environment'
  
  # 检查是否已经有足够的用户
  current_count = User.count
  if current_count >= 50
    puts "⚠️  当前已有 #{current_count} 个用户，是否继续添加？(y/n)"
    answer = STDIN.gets.chomp.downcase
    if answer != 'y'
      puts "❌ 操作已取消"
      exit
    end
  end
  
  create_test_users
end