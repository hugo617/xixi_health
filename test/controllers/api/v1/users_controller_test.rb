require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @valid_user_params = {
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
      post api_v1_users_create_url, params: @valid_user_params, as: :json
    end
    
    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_not_nil json_response["data"]["id"]
    assert_equal "测试用户", json_response["data"]["nickname"]
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
      post api_v1_users_create_url, params: invalid_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/缺少必需字段/, json_response["error"])
  end

  test "should return error for invalid email format" do
    invalid_params = @valid_user_params.deep_merge(
      user: { email: "invalid-email" }
    )
    
    assert_no_difference('User.count') do
      post api_v1_users_create_url, params: invalid_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/邮箱格式不正确/, json_response["error"])
  end

  test "should return error for invalid phone format" do
    invalid_params = @valid_user_params.deep_merge(
      user: { phone: "1234567890" }
    )
    
    assert_no_difference('User.count') do
      post api_v1_users_create_url, params: invalid_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/手机号格式不正确/, json_response["error"])
  end

  test "should return error for short password" do
    invalid_params = @valid_user_params.deep_merge(
      user: { password: "12345" }
    )
    
    assert_no_difference('User.count') do
      post api_v1_users_create_url, params: invalid_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/密码长度不能少于6位/, json_response["error"])
  end

  test "should return error for duplicate email" do
    # 先创建一个用户
    post api_v1_users_create_url, params: @valid_user_params, as: :json
    assert_response :created
    
    # 尝试创建相同邮箱的用户
    new_params = @valid_user_params.deep_merge(
      user: { phone: "13800138001" }
    )
    
    assert_no_difference('User.count') do
      post api_v1_users_create_url, params: new_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/邮箱已被使用/, json_response["error"])
  end

  test "should return error for duplicate phone" do
    # 先创建一个用户
    post api_v1_users_create_url, params: @valid_user_params, as: :json
    assert_response :created
    
    # 尝试创建相同手机号的用户
    new_params = @valid_user_params.deep_merge(
      user: { email: "different@example.com" }
    )
    
    assert_no_difference('User.count') do
      post api_v1_users_create_url, params: new_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/手机号已被使用/, json_response["error"])
  end

  test "should handle server errors gracefully" do
    # 模拟服务器错误 - 使用更简单的模拟方法
    original_service = Users::CreateService.method(:call)
    
    begin
      # 重新定义方法以抛出错误
      Users::CreateService.define_singleton_method(:call) do |params|
        raise StandardError, "Server error"
      end
      
      post api_v1_users_create_url, params: @valid_user_params, as: :json
      
      assert_response :internal_server_error
      json_response = JSON.parse(response.body)
      assert_not json_response["success"]
      assert_match(/服务器内部错误/, json_response["error"])
    ensure
      # 恢复原始方法
      Users::CreateService.define_singleton_method(:call, original_service)
    end
  end

  test "should return proper response format" do
    post api_v1_users_create_url, params: @valid_user_params, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    # 验证响应格式
    assert json_response.key?("success")
    assert json_response.key?("data")
    assert json_response.key?("error")
    
    # 验证成功响应的数据结构
    if json_response["success"]
      user_data = json_response["data"]
      assert_not_nil user_data["id"]
      assert_not_nil user_data["nickname"]
      assert_not_nil user_data["email"]
      assert_not_nil user_data["phone"]
      assert_not_nil user_data["role"]
      assert_not_nil user_data["status"]
      assert_not_nil user_data["membership_type"]
      assert_not_nil user_data["created_at"]
      assert_not_nil user_data["updated_at"]
      assert_not_nil user_data["active?"]
      assert_not_nil user_data["admin?"]
      assert_not_nil user_data["valid_member?"]
    end
  end
end