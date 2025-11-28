require "test_helper"

class H5::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      nickname: "H5 测试用户",
      email: "h5_user@example.com",
      phone: "13800138020",
      password: "securepassword123",
      password_confirmation: "securepassword123",
      status: "active",
      role: "user",
      membership_type: "no_membership"
    )
  end

  test "should show profile page for existing user" do
    get "/h5/users/#{@user.id}/profile"
    assert_response :success
    assert_includes @response.body, "我的健康报告"
    assert_includes @response.body, "H5 测试用户"
  end

  test "should show error message for missing user" do
    get "/h5/users/999999/profile"
    assert_response :success
    assert_includes @response.body, "用户不存在或已被删除"
  end
end

