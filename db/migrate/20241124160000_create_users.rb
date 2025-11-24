class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      # 核心字段
      t.string :nickname, null: false
      t.string :email, null: false
      t.string :phone, null: false
      t.string :membership_type, null: false, default: 'none'
      t.string :role, null: false, default: 'user'
      
      # 认证字段
      t.string :password_digest, null: false
      
      # 状态管理字段
      t.string :status, null: false, default: 'active'
      t.datetime :deleted_at
      
      # 时间戳
      t.timestamps
    end

    # 唯一索引
    add_index :users, :email, unique: true
    add_index :users, :phone, unique: true
    
    # 普通索引
    add_index :users, :status
    add_index :users, :role
    add_index :users, :membership_type
    add_index :users, :deleted_at
  end
end