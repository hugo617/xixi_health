require "rails_helper"

RSpec.describe HealthReports::ValidateFileService, type: :service do
  def build_uploaded_file(content:, filename:, content_type:)
    file = Tempfile.new("health_report")
    file.binmode
    file.write(content)
    file.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: file,
      filename: filename,
      type: content_type
    )
  end

  it "returns success for a valid PDF file" do
    uploaded_file = build_uploaded_file(
      content: "%PDF-1.4 test",
      filename: "健康报告_2024.pdf",
      content_type: "application/pdf"
    )

    result = described_class.call(file: uploaded_file)

    expect(result[:success]).to be true
    data = result[:data]
    expect(data[:sanitized_filename]).to match(/\A[\w\-\u4e00-\u9fa5]+\z/)
    expect(data[:extension]).to eq(".pdf")
    expect(data[:content_type]).to eq("application/pdf")
    expect(data[:size]).to be > 0
  end

  it "rejects files with unsupported mime type" do
    uploaded_file = build_uploaded_file(
      content: "plain text",
      filename: "notes.txt",
      content_type: "text/plain"
    )

    result = described_class.call(file: uploaded_file)

    expect(result[:success]).to be false
    expect(result[:error]).to include("不支持的文件类型")
  end

  it "rejects files with invalid filename after sanitization" do
    uploaded_file = build_uploaded_file(
      content: "%PDF-1.4 test",
      filename: "...",
      content_type: "application/pdf"
    )

    result = described_class.call(file: uploaded_file)

    expect(result[:success]).to be false
    expect(result[:error]).to include("文件名包含不允许的字符")
  end
end

