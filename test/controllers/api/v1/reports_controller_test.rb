require "test_helper"

class Api::V1::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      nickname: "测试用户",
      email: "testuser@example.com",
      phone: "13800138000",
      password: "securepassword123",
      password_confirmation: "securepassword123",
      status: "active",
      role: "user",
      membership_type: "no_membership"
    )
    
    @valid_report_params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test",
        file_path: "/uploads/reports/test_report.pdf",
        description: "测试报告"
      }
    }
    
    @existing_report = Report.create!(
      user_id: @user.id,
      report_type: "protein_test",
      status: "normal_result",
      file_path: "/uploads/reports/existing_report.pdf",
      description: "现有测试报告"
    )
  end

  # 测试创建报告
  test "should create report with valid parameters" do
    assert_difference('Report.count', 1) do
      post api_v1_reports_create_url, params: @valid_report_params, as: :json
    end
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_not_nil json_response["data"]["id"]
    assert_equal "blood_test", json_response["data"]["report_type"]
    assert_equal @user.id, json_response["data"]["user_id"]
  end

  test "should return error for missing required fields" do
    invalid_params = {
      report: {
        user_id: "",
        report_type: "",
        file_path: ""
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: invalid_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/缺少必需字段/, json_response["error"])
  end

  test "should return error for invalid user" do
    invalid_params = {
      report: {
        user_id: 99999,
        report_type: "blood_test",
        file_path: "/uploads/reports/test.pdf"
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: invalid_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/用户不存在/, json_response["error"])
  end

  # 测试更新报告
  test "should update report with valid parameters" do
    update_params = {
      report_id: @existing_report.id,
      report: {
        status: "abnormal_mild",
        file_size: 2048000,
        description: "更新后的报告描述"
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "abnormal_mild", json_response["data"]["status"]
    assert_equal 2048000, json_response["data"]["file_size"]
    assert_equal "更新后的报告描述", json_response["data"]["description"]
  end

  test "should return error for non-existent report" do
    update_params = {
      report_id: 99999,
      report: {
        status: "normal_result"
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/报告不存在/, json_response["error"])
  end

  test "should return error when no update fields provided" do
    update_params = {
      report_id: @existing_report.id,
      report: {}
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/没有提供有效的更新字段/, json_response["error"])
  end

  # 测试删除报告
  test "should delete report with final result status" do
    delete_params = {
      report_id: @existing_report.id
    }
    
    assert_difference('Report.where(deleted_at: nil).count', -1) do
      post api_v1_reports_delete_url, params: delete_params, as: :json
    end
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal @existing_report.id, json_response["data"]["report_id"]
    assert_not_nil json_response["data"]["deleted_at"]
  end

  test "should return error for non-existent report deletion" do
    delete_params = {
      report_id: 99999
    }
    
    assert_no_difference('Report.where(deleted_at: nil).count') do
      post api_v1_reports_delete_url, params: delete_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/报告不存在/, json_response["error"])
  end

  test "should return error when deleting non-final result report" do
    pending_report = Report.create!(
      user_id: @user.id,
      report_type: "gene_test",
      status: "pending_generation",
      file_path: "/uploads/reports/pending_report.pdf",
      description: "待生成报告"
    )
    
    delete_params = {
      report_id: pending_report.id
    }
    
    assert_no_difference('Report.where(deleted_at: nil).count') do
      post api_v1_reports_delete_url, params: delete_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/只有最终结果状态的报告才能删除/, json_response["error"])
  end

  # 测试搜索报告
  test "should search reports successfully" do
    search_params = {
      filters: {
        user_id: @user.id,
        report_type: "protein_test"
      },
      pagination: {
        page: 1,
        per_page: 10
      }
    }
    
    post api_v1_reports_search_url, params: search_params, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_not_empty json_response["data"]["reports"]
    assert_equal @existing_report.id, json_response["data"]["reports"].first["id"]
    assert_not_nil json_response["data"]["pagination"]
  end

  test "should return empty result for no matching reports" do
    search_params = {
      filters: {
        user_id: 99999
      }
    }
    
    post api_v1_reports_search_url, params: search_params, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_empty json_response["data"]["reports"]
    assert_equal 0, json_response["data"]["pagination"]["total_count"]
  end
end