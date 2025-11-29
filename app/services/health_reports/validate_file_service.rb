# frozen_string_literal: true

require "marcel"

module HealthReports
  # 报告上传文件验证服务
  # 负责统一处理文件名、大小和 MIME 类型校验
  class ValidateFileService
    MAX_FILE_SIZE = 200.megabytes

    # 允许的 MIME 类型
    ALLOWED_MIME_TYPES = %w[
      application/pdf
      image/jpeg
      image/png
    ].freeze

    MIME_EXTENSION_MAP = {
      "application/pdf" => ".pdf",
      "image/jpeg"      => ".jpg",
      "image/png"       => ".png"
    }.freeze

    # 允许的文件名字符（不含扩展名）
    # 字母、数字、下划线、连字符、中文字符
    FILENAME_WHITELIST_REGEX = /\A[\w\-\u4e00-\u9fa5]+\z/.freeze

    def self.call(params = {})
      new(params).execute
    end

    def initialize(params = {})
      @uploaded_file = params[:file] || params[:uploaded_file]
    end

    def execute
      return failure("文件不能为空") if @uploaded_file.blank?

      size = extract_file_size(@uploaded_file)
      return failure("文件大小无效") if size <= 0

      if size > MAX_FILE_SIZE
        return failure("文件大小不能超过#{MAX_FILE_SIZE / 1.megabyte}MB")
      end

      original_filename = extract_original_filename(@uploaded_file)
      base_name = File.basename(original_filename.to_s, ".*")
      sanitized_base_name = sanitize_filename(base_name)

      if sanitized_base_name.blank? || !sanitized_base_name.match?(FILENAME_WHITELIST_REGEX)
        return failure("文件名包含不允许的字符")
      end

      mime_type = detect_mime_type(@uploaded_file, original_filename)
      unless ALLOWED_MIME_TYPES.include?(mime_type)
        return failure("不支持的文件类型：#{mime_type.presence || '未知类型'}")
      end

      extension = MIME_EXTENSION_MAP[mime_type]

      data = {
        original_filename: original_filename,
        sanitized_filename: sanitized_base_name,
        size: size,
        content_type: mime_type,
        extension: extension
      }

      { success: true, data: data, error: nil }
    rescue StandardError => e
      Rails.logger.error "HealthReports::ValidateFileService error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      failure("文件验证失败，请稍后重试")
    end

    private

    def failure(message)
      { success: false, data: nil, error: message }
    end

    def extract_file_size(uploaded_file)
      if uploaded_file.respond_to?(:size)
        uploaded_file.size.to_i
      elsif uploaded_file.respond_to?(:bytesize)
        uploaded_file.bytesize.to_i
      else
        0
      end
    end

    def extract_original_filename(uploaded_file)
      if uploaded_file.respond_to?(:original_filename)
        uploaded_file.original_filename.to_s
      elsif uploaded_file.respond_to?(:path)
        File.basename(uploaded_file.path.to_s)
      else
        "health_report"
      end
    end

    def sanitize_filename(name)
      return "" if name.blank?

      sanitized = name.to_s.gsub(/[^\w\-\u4e00-\u9fa5]/, "_")
      sanitized = sanitized.gsub(/_+/, "_")
      sanitized.sub(/\A_+/, "").sub(/_+\z/, "")
    end

    def detect_mime_type(uploaded_file, original_filename)
      Marcel::MimeType.for(
        uploaded_file,
        name: original_filename,
        declared_type: uploaded_file.respond_to?(:content_type) ? uploaded_file.content_type : nil
      ).to_s
    rescue StandardError => e
      Rails.logger.warn "HealthReports::ValidateFileService MIME detect fallback: #{e.class} - #{e.message}"
      uploaded_file.respond_to?(:content_type) ? uploaded_file.content_type.to_s : ""
    end
  end
end

