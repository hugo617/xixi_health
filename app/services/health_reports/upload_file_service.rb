# frozen_string_literal: true

require "securerandom"
require "fileutils"

module HealthReports
  # 报告文件上传服务
  # 负责安全地将用户上传的报告文件保存到 storage/reports 目录下
  # 并返回用于持久化到数据库的相对路径等元数据
  class UploadFileService
    def self.call(params = {})
      new(params).execute
    end

    def initialize(params = {})
      @user = params[:user]
      @user_id = params[:user_id]
      @uploaded_file = params[:file] || params[:uploaded_file]
      @existing_file_path = params[:existing_file_path]
    end

    def execute
      return failure("上传文件不能为空") if @uploaded_file.blank?

      user = resolve_user
      return failure("用户不存在") unless user

      validation_result = HealthReports::ValidateFileService.call(file: @uploaded_file)
      return failure(validation_result[:error]) unless validation_result[:success]

      validated = validation_result[:data]

      base_dir = storage_base_dir
      uuid = SecureRandom.uuid
      user_dir = "user_#{user.id}"

      stored_filename = "#{uuid}_#{validated[:sanitized_filename]}#{validated[:extension]}"
      relative_path = File.join(user_dir, stored_filename)

      absolute_dir = base_dir.join(user_dir)
      FileUtils.mkdir_p(absolute_dir)

      absolute_path = absolute_dir.join(stored_filename)
      write_file(absolute_path, @uploaded_file)

      delete_existing_file_if_needed(@existing_file_path, base_dir)

      data = {
        file_path: relative_path,
        file_size: validated[:size],
        content_type: validated[:content_type],
        original_filename: validated[:original_filename],
        stored_filename: stored_filename,
        absolute_path: absolute_path.to_s
      }

      { success: true, data: data, error: nil }
    rescue StandardError => e
      Rails.logger.error "HealthReports::UploadFileService error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      failure("文件上传失败，请稍后重试")
    end

    private

    def failure(message)
      { success: false, data: nil, error: message }
    end

    def resolve_user
      return @user if @user.is_a?(User)
      return User.find_by(id: @user_id) if @user_id.present?

      nil
    end

    def storage_base_dir
      configured = Rails.application.config.x.reports_storage
      base_dir = configured&.base_dir || Rails.root.join("storage", "reports")
      FileUtils.mkdir_p(base_dir) unless File.directory?(base_dir)
      Pathname.new(base_dir)
    end

    def write_file(path, uploaded_file)
      # 使用 Pathname 确保是绝对路径
      pathname = Pathname.new(path)

      # 额外安全检查：路径必须位于 storage_base_dir 下
      base = storage_base_dir.realpath
      target_dir = pathname.dirname
      target_dir = target_dir.realpath if target_dir.exist?

      unless target_dir.to_s.start_with?(base.to_s)
        raise StandardError, "非法文件保存路径"
      end

      File.open(pathname, "wb") do |file|
        if uploaded_file.respond_to?(:rewind)
          uploaded_file.rewind
        end

        if uploaded_file.respond_to?(:read)
          IO.copy_stream(uploaded_file, file)
        else
          file.write(uploaded_file.to_s)
        end
      end
    end

    def delete_existing_file_if_needed(existing_file_path, base_dir)
      return if existing_file_path.blank?

      # 仅删除位于 storage/reports 下的新存储结构中的文件
      relative = Pathname.new(existing_file_path.to_s)
      target = base_dir.join(relative).cleanpath

      base_real = base_dir.exist? ? base_dir.realpath : base_dir
      return unless target.to_s.start_with?(base_real.to_s)

      File.delete(target) if File.exist?(target)
    rescue StandardError => e
      Rails.logger.warn "HealthReports::UploadFileService delete existing file warning: #{e.class} - #{e.message}"
    end
  end
end
