require "rails_helper"

RSpec.describe HealthReports::DownloadFileService, type: :service do
  let!(:user) do
    User.create!(
      nickname: "下载测试用户",
      email: "download_user@example.com",
      phone: "13900139000",
      password: "securepassword123",
      password_confirmation: "securepassword123",
      status: "active",
      role: "user",
      membership_type: "no_membership"
    )
  end

  let!(:report) do
    relative_path = "user_#{user.id}/download_service_test.pdf"
    base_dir = Rails.application.config.x.reports_storage.base_dir || Rails.root.join("storage", "reports")
    absolute_path = Pathname.new(base_dir).join(relative_path)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.binwrite(absolute_path, "%PDF-1.4 download test")

    Report.create!(
      user: user,
      report_type: "blood_test",
      status: "normal_result",
      file_path: relative_path,
      file_size: File.size(absolute_path),
      description: "DownloadService 测试报告",
      report_date: Time.current
    )
  end

  it "returns success for valid report and file" do
    result = described_class.call(
      report_id: report.id,
      current_user: user,
      ip_address: "127.0.0.1",
      inline: false
    )

    expect(result[:success]).to be true
    data = result[:data]
    expect(data[:report]).to eq(report)
    expect(File.exist?(data[:file_path])).to be true
    expect(data[:content_type]).to eq("application/pdf")
    expect(data[:disposition]).to eq("attachment")

    log = FileAccessLog.order(created_at: :desc).first
    expect(log).not_to be_nil
    expect(log.report_id).to eq(report.id)
    expect(log.user_id).to eq(user.id)
  end

  it "returns error when report does not exist" do
    result = described_class.call(
      report_id: -1,
      current_user: user,
      ip_address: "127.0.0.1",
      inline: false
    )

    expect(result[:success]).to be false
    expect(result[:error]).to include("报告不存在")
  end
end

