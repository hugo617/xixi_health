require "test_helper"

class Users::CreateServiceTest < ActiveSupport::TestCase
  setup do
    @valid_params = {
      user: {
        nickname: "测试用户",
        email: "testuser@example.com",
        phone: "13800138000",
        password: "securepassword123",
        password_confirmation: "securepassword123",
        status: "active",
        role: "user",
        membership_type: "no_membership"
      }
    }
  end

  test "should create user with valid parameters" do
    assert_difference('User.count', 1) do
      result = Users::CreateService.call(@valid_params)
      assert result[:success]
      assert_not_nil result[:data]
      assert_nil result[:error]
    end
  end

  test "should return error for missing required fields" do
    invalid_params = {
      user: {
        nickname: "",
        email: "",
        phone: "",
        password: ""
      }
    }
    
    assert_no_difference('User.count') do
      result = Users::CreateService.call(invalid_params)
      assert_not result[:success]
      assert_nil result[:data]
      assert_match(/缺少必需字段/, result[:error])
    end
  end

  test "should return error for invalid email format" do
    invalid_params = @valid_params.deep_merge(
      user: { email: "invalid-email" }
    )
    
    assert_no_difference('User.count') do
      result = Users::CreateService.call(invalid_params)
      assert_not result[:success]
      assert_nil result[:data]
      assert_match(/邮箱格式不正确/, result[:error])
    end
  end

  test "should return error for invalid phone format" do
    invalid_params = @valid_params.deep_merge(
      user: { phone: "1234567890" }
    )
    
    assert_no_difference('User.count') do
      result = Users::CreateService.call(invalid_params)
      assert_not result[:success]
      assert_nil result[:data]
      assert_match(/手机号格式不正确/, result[:error])
    end
  end

  test "should return error for short password" do
    invalid_params = @valid_params.deep_merge(
      user: { password: "12345" }
    )
    
    assert_no_difference('User.count') do
      result = Users::CreateService.call(invalid_params)
      assert_not result[:success]
      assert_nil result[:data]
      assert_match(/密码长度不能少于6位/, result[:error])
    end
  end

  test "should return error for duplicate email" do
    # 先创建一个用户
    Users::CreateService.call(@valid_params)
    
    # 尝试创建相同邮箱的用户
    new_params = @valid_params.deep_merge(
      user: { phone: "13800138001" }
    )
    
    assert_no_difference('User.count') do
      result = Users::CreateService.call(new_params)
      assert_not result[:success]
      assert_nil result[:data]
      assert_match(/邮箱已被使用/, result[:error])
    end
  end

  test "should return error for duplicate phone" do
    # 先创建一个用户
    Users::CreateService.call(@valid_params)
    
    # 尝试创建相同手机号的用户
    new_params = @valid_params.deep_merge(
      user: { email: "different@example.com" }
    )
    
    assert_no_difference('User.count') do
      result = Users::CreateService.call(new_params)
      assert_not result[:success]
      assert_nil result[:data]
      assert_match(/手机号已被使用/, result[:error])
    end
  end

  test "should set default values when not provided" do
    params_with_defaults = {
      user: {
        nickname: "测试用户2",
        email: "testuser2@example.com",
        phone: "13800138002",
        password: "securepassword123"
        # 其他字段未提供，应该使用默认值
      }
    }
    
    result = Users::CreateService.call(params_with_defaults)
    assert result[:success]
    
    # 验证结果数据 - 使用字符串键因为 as_json 返回字符串键
    user_data = result[:data]
    assert_not_nil user_data["id"], "User ID should not be nil"
    
    # 验证默认值在返回的数据中
    assert_equal "active", user_data["status"]
    assert_equal "user", user_data["role"]
    assert_equal "no_membership", user_data["membership_type"]
  end

  test "should return proper data structure on success" do
    result = Users::CreateService.call(@valid_params)
    
    assert result[:success]
    assert_nil result[:error]
    
    user_data = result[:data]
    
    # 基本字段验证 - as_json 返回字符串键
    assert_not_nil user_data["id"], "User ID should not be nil"
    assert_equal "测试用户", user_data["nickname"]
    assert_equal "testuser@example.com", user_data["email"]
    assert_equal "13800138000", user_data["phone"]
    
    # 验证时间戳存在
    assert_not_nil user_data["created_at"], "Created at should not be nil"
    assert_not_nil user_data["updated_at"], "Updated at should not be nil"
    
    # 验证默认值
    assert_equal "user", user_data["role"]
    assert_equal "active", user_data["status"]
    assert_equal "no_membership", user_data["membership_type"]
    
    # 验证方法结果
    assert user_data["active?"], "User should be active"
    assert_not user_data["admin?"], "User should not be admin"
    assert_not user_data["valid_member?"], "User should not be valid member"
  end

  test "should handle standard errors gracefully" do
    # 模拟标准错误 - 使用更简单的模拟方法
    original_new_method = User.method(:new)
    
    begin
      # 重新定义方法以抛出错误
      User.define_singleton_method(:new) do |attributes|
        raise StandardError, "Database error"
      end
      
      result = Users::CreateService.call(@valid_params)
      
      assert_not result[:success]
      assert_nil result[:data]
      assert_match(/创建用户失败，请稍后重试/, result[:error])
    ensure
      # 恢复原始方法
      User.define_singleton_method(:new, original_new_method)
    end
  end
end