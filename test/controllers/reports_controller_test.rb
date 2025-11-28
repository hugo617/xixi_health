require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get reports_index_url
    assert_response :success
  end

  test "should preview existing report pdf" do
    user = User.create!(
      nickname: "控制器预览用户",
      email: "controller_preview@example.com",
      phone: "13800138011",
      password: "securepassword123",
      password_confirmation: "securepassword123",
      status: "active",
      role: "user",
      membership_type: "no_membership"
    )

    relative_path = "/uploads/reports/controller_preview.pdf"
    absolute_path = Rails.root.join("public", relative_path.delete_prefix("/"))
    FileUtils.mkdir_p(absolute_path.dirname)
    File.binwrite(absolute_path, "%PDF-1.4 test")

    report = Report.create!(
      user_id: user.id,
      report_type: "protein_test",
      status: "normal_result",
      file_path: relative_path,
      file_size: 2048,
      description: "控制器预览测试报告"
    )

    get report_preview_url(report)
    assert_response :success
    assert_match(/报告预览/, @response.body)
  end

  test "should download existing report pdf" do
    user = User.create!(
      nickname: "控制器下载用户",
      email: "controller_download@example.com",
      phone: "13800138012",
      password: "securepassword123",
      password_confirmation: "securepassword123",
      status: "active",
      role: "user",
      membership_type: "no_membership"
    )

    relative_path = "/uploads/reports/controller_download.pdf"
    absolute_path = Rails.root.join("public", relative_path.delete_prefix("/"))
    FileUtils.mkdir_p(absolute_path.dirname)
    File.binwrite(absolute_path, "%PDF-1.4 test")

    report = Report.create!(
      user_id: user.id,
      report_type: "gene_test",
      status: "normal_result",
      file_path: relative_path,
      file_size: 4096,
      description: "控制器下载测试报告"
    )

    get report_download_url(report)
    assert_response :success
    assert_equal "application/pdf", @response.media_type
    assert_includes @response.header["Content-Disposition"], "attachment"
  end

  test "should show friendly error when preview file missing" do
    user = User.create!(
      nickname: "缺失文件用户",
      email: "missing_file@example.com",
      phone: "13800138013",
      password: "securepassword123",
      password_confirmation: "securepassword123",
      status: "active",
      role: "user",
      membership_type: "no_membership"
    )

    relative_path = "/uploads/reports/missing_preview.pdf"

    report = Report.create!(
      user_id: user.id,
      report_type: "blood_test",
      status: "normal_result",
      file_path: relative_path,
      file_size: 0,
      description: "缺失文件测试报告"
    )

    get report_preview_url(report)
    assert_response :not_found
    assert_match(/报告文件不存在|报告文件不存在或已被删除/, @response.body)
  end
end
