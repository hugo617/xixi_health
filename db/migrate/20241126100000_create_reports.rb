class CreateReports < ActiveRecord::Migration[7.0]
  def change
    create_table :reports do |t|
      # 核心关联字段
      t.references :user, null: false, foreign_key: true, comment: '关联用户ID'
      
      # 报告基本信息
      t.string :report_type, null: false, comment: '报告类型：protein_test, gene_test等'
      t.string :file_path, null: false, comment: '报告文件存储路径或URL'
      
      # 状态管理
      t.string :status, null: false, default: 'pending_generation', comment: '报告状态：进度类(待生成/审核中)/结果正常类/结果异常类(轻/中/重度)/特殊类(待补充/待修订)'
      
      # 报告元数据
      t.datetime :report_date, comment: '报告生成日期'
      t.integer :file_size, comment: '报告文件大小（字节）'
      t.text :description, comment: '报告描述或备注'
      
      # 软删除支持
      t.datetime :deleted_at, comment: '软删除时间戳'
      
      # 标准时间戳
      t.timestamps
    end

    # 复合索引（用户ID + 报告类型）- 最常用的查询组合
    add_index :reports, [:user_id, :report_type], name: 'idx_reports_user_type'
    
    # 状态索引 - 用于状态筛选
    add_index :reports, :status, name: 'idx_reports_status'
    
    # 报告类型索引 - 用于类型统计
    add_index :reports, :report_type, name: 'idx_reports_type'
    
    # 报告日期索引 - 用于时间范围查询
    add_index :reports, :report_date, name: 'idx_reports_date'
    
    # 软删除索引 - 用于逻辑删除数据筛选
    add_index :reports, :deleted_at, name: 'idx_reports_deleted_at'
    
    # 文件大小索引 - 用于统计分析（可选）
    add_index :reports, :file_size, name: 'idx_reports_file_size'
  end
end