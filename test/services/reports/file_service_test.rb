require "test_helper"

class Reports::FileServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      nickname: "预览测试用户",
      email: "preview_user@example.com",
      phone: "13800138010",
      password: "securepassword123",
      password_confirmation: "securepassword123",
      status: "active",
      role: "user",
      membership_type: "no_membership"
    )

    @pdf_relative_path = "/uploads/reports/test_preview_service.pdf"
    @pdf_absolute_path = Rails.root.join("public", @pdf_relative_path.delete_prefix("/"))
    FileUtils.mkdir_p(@pdf_absolute_path.dirname)
    File.binwrite(@pdf_absolute_path, "%PDF-1.4 test")

    @report = Report.create!(
      user_id: @user.id,
      report_type: "blood_test",
      status: "normal_result",
      file_path: @pdf_relative_path,
      file_size: 1024,
      description: "Service 预览测试报告"
    )
  end

  test "should return success with valid pdf file" do
    result = Reports::FileService.call(report_id: @report.id)

    assert result[:success]
    assert_nil result[:error]
    data = result[:data]

    assert_equal @report, data[:report]
    assert_equal @pdf_relative_path, data[:relative_url]
    assert_equal "application/pdf", data[:content_type]
    assert File.exist?(data[:file_path])
  end

  test "should return error when report does not exist" do
    result = Reports::FileService.call(report_id: -1)

    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/报告不存在/, result[:error])
  end

  test "should return error when file path is blank" do
    @report.update!(file_path: nil)

    result = Reports::FileService.call(report_id: @report.id)

    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/报告文件不存在/, result[:error])
  end

  test "should return error when file is outside managed directory" do
    @report.update!(file_path: "/other/path/invalid.pdf")

    result = Reports::FileService.call(report_id: @report.id)

    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/路径无效/, result[:error])
  end

  test "should return error when file does not exist on disk" do
    File.delete(@pdf_absolute_path) if File.exist?(@pdf_absolute_path)

    result = Reports::FileService.call(report_id: @report.id)

    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/不存在或已被删除/, result[:error])
  end

  test "should return error when file is not pdf" do
    non_pdf_relative = "/uploads/reports/test_preview_service.docx"
    non_pdf_absolute = Rails.root.join("public", non_pdf_relative.delete_prefix("/"))
    FileUtils.mkdir_p(non_pdf_absolute.dirname)
    File.binwrite(non_pdf_absolute, "dummy")

    @report.update!(file_path: non_pdf_relative)

    result = Reports::FileService.call(report_id: @report.id)

    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/仅支持预览PDF/, result[:error])
  end
end

