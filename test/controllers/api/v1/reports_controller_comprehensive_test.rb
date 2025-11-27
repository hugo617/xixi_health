require "test_helper"

class Api::V1::ReportsControllerComprehensiveTest < ActionDispatch::IntegrationTest
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
    
    @another_user = User.create!(
      nickname: "另一个用户",
      email: "another@example.com",
      phone: "13900139000",
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
    
    # 创建一个可删除的报告（最终结果状态）
    @deletable_report = Report.create!(
      user_id: @user.id,
      report_type: "protein_test",
      status: "normal_result",
      file_path: "/uploads/reports/deletable_report.pdf",
      description: "可删除的测试报告",
      report_date: Date.current
    )
    
    # 创建一个不可删除的报告（进行中状态）
    @non_deletable_report = Report.create!(
      user_id: @user.id,
      report_type: "gene_test",
      status: "pending_generation",
      file_path: "/uploads/reports/non_deletable_report.pdf",
      description: "不可删除的测试报告"
    )
  end

  # ====================================
  # 创建接口测试
  # ====================================

  test "should create report with all valid parameters" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test",
        status: "normal_result",
        file_path: "/uploads/reports/comprehensive_test.pdf",
        report_date: "2024-11-26",
        file_size: 1024000,
        description: "完整的测试报告"
      }
    }
    
    assert_difference('Report.count', 1) do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    data = json_response["data"]
    assert_equal @user.id, data["user_id"]
    assert_equal "blood_test", data["report_type"]
    assert_equal "normal_result", data["status"]
    assert_equal "/uploads/reports/comprehensive_test.pdf", data["file_path"]
    assert_equal "2024-11-26", data["report_date"].to_date.to_s
    assert_equal 1024000, data["file_size"]
    assert_equal "完整的测试报告", data["description"]
  end

  test "should create report with minimal required parameters" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "protein_test",
        file_path: "/uploads/reports/minimal_test.pdf"
      }
    }
    
    assert_difference('Report.count', 1) do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    data = json_response["data"]
    assert_equal @user.id, data["user_id"]
    assert_equal "protein_test", data["report_type"]
    assert_equal "pending_generation", data["status"] # 默认值
    assert_equal "/uploads/reports/minimal_test.pdf", data["file_path"]
    assert_not_nil data["report_date"] # 应该使用当前时间
    assert_equal 0, data["file_size"] # 默认值
  end

  # 参数缺失测试
  test "should return error when user_id is missing" do
    params = {
      report: {
        report_type: "blood_test",
        file_path: "/uploads/reports/test.pdf"
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/用户ID/, json_response["error"])
  end

  test "should return error when report_type is missing" do
    params = {
      report: {
        user_id: @user.id,
        file_path: "/uploads/reports/test.pdf"
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/报告类型/, json_response["error"])
  end

  test "should return error when file_path is missing" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test"
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/文件路径/, json_response["error"])
  end

  # 参数格式验证测试
  test "should return error for invalid user_id" do
    params = {
      report: {
        user_id: 99999,
        report_type: "blood_test",
        file_path: "/uploads/reports/test.pdf"
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/用户不存在/, json_response["error"])
  end

  test "should return error for invalid report_type" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "invalid_type",
        file_path: "/uploads/reports/test.pdf"
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/无效的报告类型/, json_response["error"])
  end

  test "should return error for invalid status" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test",
        status: "invalid_status",
        file_path: "/uploads/reports/test.pdf"
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/无效的报告状态/, json_response["error"])
  end

  test "should return error for invalid file_path format" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test",
        file_path: "invalid_path"
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/文件路径格式不正确/, json_response["error"])
  end

  test "should return error for negative file_size" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test",
        file_path: "/uploads/reports/test.pdf",
        file_size: -1000
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/文件大小不能为负数/, json_response["error"])
  end

  test "should return error for file_size exceeding limit" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test",
        file_path: "/uploads/reports/test.pdf",
        file_size: 200.megabytes
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/文件大小不能超过/, json_response["error"])
  end

  test "should return error for future report_date" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test",
        file_path: "/uploads/reports/test.pdf",
        report_date: 1.day.from_now.to_date.to_s
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/报告日期不能是未来日期/, json_response["error"])
  end

  test "should return error for invalid report_date format" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test",
        file_path: "/uploads/reports/test.pdf",
        report_date: "invalid-date"
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/报告日期格式不正确/, json_response["error"])
  end

  test "should return error for description exceeding length limit" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test",
        file_path: "/uploads/reports/test.pdf",
        description: "a" * 501
      }
    }
    
    assert_no_difference('Report.count') do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/报告描述不能超过500个字符/, json_response["error"])
  end

  # 边界条件测试
  test "should accept various valid file extensions" do
    valid_extensions = %w[pdf doc docx txt xls xlsx]
    
    valid_extensions.each do |ext|
      params = {
        report: {
          user_id: @user.id,
          report_type: "blood_test",
          file_path: "/uploads/reports/test.#{ext}"
        }
      }
      
      assert_difference('Report.count', 1) do
        post api_v1_reports_create_url, params: params, as: :json
      end
      
      assert_response :success
    end
  end

  test "should handle empty description correctly" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test",
        file_path: "/uploads/reports/test.pdf",
        description: ""
      }
    }
    
    assert_difference('Report.count', 1) do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "", json_response["data"]["description"]
  end

  test "should handle nil description correctly" do
    params = {
      report: {
        user_id: @user.id,
        report_type: "blood_test",
        file_path: "/uploads/reports/test.pdf",
        description: nil
      }
    }
    
    assert_difference('Report.count', 1) do
      post api_v1_reports_create_url, params: params, as: :json
    end
    
    assert_response :success
  end

  # ====================================
  # 更新接口测试
  # ====================================

  test "should update report with valid parameters" do
    update_params = {
      report_id: @deletable_report.id,
      report: {
        report_type: "gene_test",
        status: "abnormal_moderate",
        file_path: "/uploads/reports/updated_path.pdf",
        report_date: "2024-11-25",
        file_size: 2048000,
        description: "更新后的完整描述"
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    data = json_response["data"]
    assert_equal "gene_test", data["report_type"]
    assert_equal "abnormal_moderate", data["status"]
    assert_equal "/uploads/reports/updated_path.pdf", data["file_path"]
    assert_equal "2024-11-25", data["report_date"].to_date.to_s
    assert_equal 2048000, data["file_size"]
    assert_equal "更新后的完整描述", data["description"]
  end

  test "should update single field correctly" do
    update_params = {
      report_id: @deletable_report.id,
      report: {
        status: "abnormal_severe"
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "abnormal_severe", json_response["data"]["status"]
  end

  test "should return error when updating non-existent report" do
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
      report_id: @deletable_report.id,
      report: {}
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/没有提供有效的更新字段/, json_response["error"])
  end

  test "should return error when report_id is missing" do
    update_params = {
      report: {
        status: "normal_result"
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/报告ID不能为空/, json_response["error"])
  end

  test "should return error when updating deleted report" do
    # 先删除一个报告
    @deletable_report.update(deleted_at: Time.current)
    
    update_params = {
      report_id: @deletable_report.id,
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

  # 更新参数验证测试
  test "should return error for invalid report_type in update" do
    update_params = {
      report_id: @deletable_report.id,
      report: {
        report_type: "invalid_type"
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/无效的报告类型/, json_response["error"])
  end

  test "should return error for invalid status in update" do
    update_params = {
      report_id: @deletable_report.id,
      report: {
        status: "invalid_status"
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/无效的报告状态/, json_response["error"])
  end

  test "should return error for invalid file_path in update" do
    update_params = {
      report_id: @deletable_report.id,
      report: {
        file_path: "invalid_path"
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/文件路径格式不正确/, json_response["error"])
  end

  test "should return error for negative file_size in update" do
    update_params = {
      report_id: @deletable_report.id,
      report: {
        file_size: -1000
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/文件大小不能为负数/, json_response["error"])
  end

  test "should return error for future report_date in update" do
    update_params = {
      report_id: @deletable_report.id,
      report: {
        report_date: 1.day.from_now.to_date.to_s
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/报告日期不能是未来日期/, json_response["error"])
  end

  test "should return error for invalid report_date format in update" do
    update_params = {
      report_id: @deletable_report.id,
      report: {
        report_date: "invalid-date"
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/报告日期格式不正确/, json_response["error"])
  end

  test "should return error for description exceeding length limit in update" do
    update_params = {
      report_id: @deletable_report.id,
      report: {
        description: "a" * 501
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/报告描述不能超过500个字符/, json_response["error"])
  end

  # ====================================
  # 删除接口测试
  # ====================================

  test "should successfully delete report with final result status" do
    delete_params = {
      report_id: @deletable_report.id
    }
    
    assert_difference('Report.where(deleted_at: nil).count', -1) do
      post api_v1_reports_delete_url, params: delete_params, as: :json
    end
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    data = json_response["data"]
    assert_equal @deletable_report.id, data["report_id"]
    assert_not_nil data["deleted_at"]
    assert_equal @user.id, data["user_id"]
    assert_equal "protein_test", data["report_type"]
    assert_equal "normal_result", data["status"]
  end

  test "should return error when deleting non-existent report" do
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

  test "should return error when deleting with missing report_id" do
    delete_params = {}
    
    assert_no_difference('Report.where(deleted_at: nil).count') do
      post api_v1_reports_delete_url, params: delete_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/报告ID不能为空/, json_response["error"])
  end

  test "should return error when deleting report with non-final status" do
    delete_params = {
      report_id: @non_deletable_report.id
    }
    
    assert_no_difference('Report.where(deleted_at: nil).count') do
      post api_v1_reports_delete_url, params: delete_params, as: :json
    end
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_match(/只有最终结果状态的报告才能删除/, json_response["error"])
  end

  test "should return success when deleting already deleted report (idempotent)" do
    # 先删除报告
    @deletable_report.update(deleted_at: Time.current)
    
    delete_params = {
      report_id: @deletable_report.id
    }
    
    assert_no_difference('Report.where(deleted_at: nil).count') do
      post api_v1_reports_delete_url, params: delete_params, as: :json
    end
    
    # 幂等操作：重复删除应该返回成功
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal @deletable_report.id, json_response["data"]["report_id"]
    assert_not_nil json_response["data"]["deleted_at"]
  end

  # 权限测试 - 确保用户只能操作自己的报告
  test "should allow user to update their own report" do
    # 创建一个属于测试用户的报告
    user_report = Report.create!(
      user_id: @user.id,
      report_type: "blood_test",
      status: "normal_result",
      file_path: "/uploads/reports/user_report.pdf",
      description: "用户自己的报告"
    )
    
    update_params = {
      report_id: user_report.id,
      report: {
        description: "用户更新自己的报告"
      }
    }
    
    post api_v1_reports_update_url, params: update_params, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "用户更新自己的报告", json_response["data"]["description"]
  end

  test "should allow user to delete their own report" do
    # 创建一个属于测试用户的报告
    user_report = Report.create!(
      user_id: @user.id,
      report_type: "blood_test",
      status: "normal_result",
      file_path: "/uploads/reports/user_report.pdf",
      description: "用户自己的报告"
    )
    
    delete_params = {
      report_id: user_report.id
    }
    
    assert_difference('Report.where(deleted_at: nil).count', -1) do
      post api_v1_reports_delete_url, params: delete_params, as: :json
    end
    
    assert_response :success
  end

  # ====================================
  # 并发测试
  # ====================================

  test "should handle concurrent updates correctly" do
    # 这个测试模拟并发更新场景
    report = Report.create!(
      user_id: @user.id,
      report_type: "blood_test",
      status: "normal_result",
      file_path: "/uploads/reports/concurrent_test.pdf",
      description: "并发测试报告",
      file_size: 1000
    )
    
    # 模拟两个并发更新请求
    update_params1 = {
      report_id: report.id,
      report: {
        file_size: 2000,
        description: "第一次更新"
      }
    }
    
    update_params2 = {
      report_id: report.id,
      report: {
        file_size: 3000,
        description: "第二次更新"
      }
    }
    
    # 第一个更新请求
    post api_v1_reports_update_url, params: update_params1, as: :json
    assert_response :success
    
    # 第二个更新请求（应该也能成功）
    post api_v1_reports_update_url, params: update_params2, as: :json
    assert_response :success
    
    # 验证最终状态
    report.reload
    assert_equal 3000, report.file_size
    assert_equal "第二次更新", report.description
  end

  # ====================================
  # 响应格式测试
  # ====================================

  test "should return consistent response format for successful operations" do
    # 创建成功响应格式检查
    post api_v1_reports_create_url, params: @valid_report_params, as: :json
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?("success")
    assert json_response.key?("data")
    assert json_response.key?("error")
    assert_equal true, json_response["success"]
    assert_nil json_response["error"]
    assert json_response["data"].is_a?(Hash)
  end

  test "should return consistent response format for failed operations" do
    # 创建失败响应格式检查
    invalid_params = {
      report: {
        user_id: "",
        report_type: "",
        file_path: ""
      }
    }
    
    post api_v1_reports_create_url, params: invalid_params, as: :json
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response.key?("success")
    assert json_response.key?("data")
    assert json_response.key?("error")
    assert_equal false, json_response["success"]
    assert_nil json_response["data"]
    assert json_response["error"].is_a?(String)
    assert_not_empty json_response["error"]
  end
end