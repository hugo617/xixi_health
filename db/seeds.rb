# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 开始创建测试数据..."

# 创建用户数据
users = []
base_phone = 13800138000

8.times do |i|
  email = "user#{i + 1}@example.com"
  nickname = "用户#{i + 1}"
  phone = (base_phone + i).to_s
  
  user = User.find_or_create_by!(email: email) do |u|
    u.nickname = nickname
    u.phone = phone
    u.status = %w[active inactive].sample
    u.role = 'user'
    u.membership_type = %w[session_card monthly_card annual_card no_membership].sample
    u.password = 'password123'
    u.password_confirmation = 'password123'
  end
  
  users << user
  puts "✅ 创建用户: #{user.nickname} (#{user.email})"
rescue ActiveRecord::RecordInvalid => e
  puts "⚠️  用户创建失败: #{email} - #{e.message}"
  next
end

# 确保有用户存在
if users.empty?
  default_user = User.create!(
    nickname: '测试用户',
    email: 'test@example.com',
    phone: '13000000000',
    status: 'active',
    role: 'user',
    membership_type: 'session_card',
    password: 'password123',
    password_confirmation: 'password123'
  )
  users << default_user
  puts "✅ 创建默认测试用户"
end

puts "📊 用户总数: #{User.count}"

# 创建报告数据
report_types = %w[protein_test gene_test blood_test urine_test other_test]
statuses = %w[pending_generation under_review normal_result abnormal_mild abnormal_moderate abnormal_severe pending_supplement pending_revision]

# 报告描述模板
descriptions = [
  '血液常规检查报告，包含血红蛋白、白细胞计数等指标',
  '尿液分析检测报告，检测尿蛋白、尿糖等项目',
  '基因检测报告，分析遗传疾病风险',
  '蛋白质组学检测报告，分析血清蛋白表达谱',
  '生化全套检查报告，包含肝功能、肾功能等指标',
  '甲状腺功能检测报告，检测TSH、T3、T4等指标',
  '心血管风险评估报告，分析血脂、血压等指标',
  '糖尿病筛查报告，检测空腹血糖、糖化血红蛋白',
  '肿瘤标志物检测报告，检测AFP、CEA等指标',
  '骨密度检测报告，评估骨质疏松风险',
  '过敏原检测报告，检测常见过敏原IgE抗体',
  '维生素水平检测报告，检测维生素D、B12等',
  '重金属中毒筛查报告，检测血铅、血汞等',
  '免疫功能评估报告，检测免疫球蛋白、补体等',
  '凝血功能检测报告，检测PT、APTT等指标',
  '内分泌激素检测报告，检测性激素、皮质醇等'
]

# 文件大小范围（字节）
file_sizes = [102400, 204800, 512000, 1048576, 2097152, 5242880, 10485760, 20971520]

puts "🧪 开始创建报告数据..."

# 为每个用户创建多个报告
users.each_with_index do |user, user_index|
  # 每个用户创建5-6个报告
  report_count = rand(5..6)
  
  report_count.times do |i|
    report_index = user_index * 10 + i + 1
    
    report_type = report_types.sample
    status = statuses.sample
    file_size = file_sizes.sample
    description = descriptions.sample
    report_date = rand(1..90).days.ago
    
    # 创建报告
    report = Report.find_or_create_by!(user: user, report_type: report_type, report_date: report_date) do |r|
      r.file_path = "/reports/user_#{user.id}/report_#{report_index}.pdf"
      r.file_size = file_size
      r.status = status
      r.description = description
      r.created_at = report_date
      r.updated_at = report_date + rand(1..24).hours
    end
    
    puts "✅ 创建报告 ##{report_index}: #{report_type} - #{status} (用户: #{user.nickname})"
  end
end

# 确保总共有40个报告
additional_reports_needed = 40 - Report.count
if additional_reports_needed > 0
  additional_reports_needed.times do |i|
    user = users.sample
    report_type = report_types.sample
    status = statuses.sample
    file_size = file_sizes.sample
    description = descriptions.sample
    report_date = rand(1..90).days.ago
    
    report = Report.create!(
      user: user,
      report_type: report_type,
      file_path: "/reports/user_#{user.id}/additional_report_#{i + 1}.pdf",
      file_size: file_size,
      status: status,
      description: description,
      report_date: report_date,
      created_at: report_date,
      updated_at: report_date + rand(1..24).hours
    )
    
    puts "✅ 创建额外报告: #{report_type} - #{status}"
  end
end

puts "📊 报告总数: #{Report.count}"
puts "🎉 测试数据创建完成！"