namespace :reports do
  desc "扫描 reports.file_path 中的可疑路径（路径遍历、外部URL、异常绝对路径）"
  task scan_file_paths: :environment do
    total = Report.count
    puts "开始扫描 reports.file_path，总记录数：#{total}"

    suspicious = []

    Report.find_each(batch_size: 1000) do |report|
      path = report.file_path.to_s

      next if path.blank?

      if path.include?("../") || path.include?("..\\")
        suspicious << { id: report.id, reason: "路径遍历字符(../ 或 ..\\)", file_path: path }
        next
      end

      if path.start_with?("http://", "https://")
        suspicious << { id: report.id, reason: "外部URL", file_path: path }
        next
      end

      if !path.start_with?("/uploads/reports/") && path.start_with?("/")
        suspicious << { id: report.id, reason: "异常绝对路径", file_path: path }
        next
      end

      if path =~ /\A[A-Za-z]:[\\\/]/
        suspicious << { id: report.id, reason: "Windows 绝对路径", file_path: path }
        next
      end
    end

    if suspicious.empty?
      puts "扫描完成，未发现可疑 file_path 记录。"
    else
      puts "扫描完成，发现 #{suspicious.size} 条可疑记录："
      suspicious.first(100).each do |item|
        puts "  Report ##{item[:id]}: #{item[:reason]} => #{item[:file_path]}"
      end

      if suspicious.size > 100
        puts "  …… 其余 #{suspicious.size - 100} 条未全部列出。"
      end

      puts "注意：该任务只做检测，不会修改任何数据。"
    end
  end

  desc "将 legacy public/uploads/reports 下的文件迁移到 storage/reports 结构（仅迁移安全路径）"
  task migrate_legacy_files_to_storage: :environment do
    config = Rails.application.config.x.reports_storage
    unless config&.mode.to_s == "secure"
      puts "当前 REPORTS_STORAGE_MODE 不是 secure，跳过迁移。请设置为 secure 后再执行。"
      return
    end

    base_legacy_dir = Rails.root.join("public", "uploads", "reports")
    base_secure_dir = config.base_dir || Rails.root.join("storage", "reports")

    migrated = 0
    skipped_missing = 0
    skipped_invalid = 0

    Report.find_each(batch_size: 100) do |report|
      path = report.file_path.to_s
      next unless path.start_with?("/uploads/reports/")

      if path.include?("../") || path.include?("..\\")
        skipped_invalid += 1
        next
      end

      legacy_relative = path.delete_prefix("/uploads/reports/")
      legacy_absolute = base_legacy_dir.join(legacy_relative)

      unless File.exist?(legacy_absolute)
        skipped_missing += 1
        next
      end

      File.open(legacy_absolute, "rb") do |file_io|
        upload_result = HealthReports::UploadFileService.call(
          user: report.user,
          file: file_io,
          existing_file_path: report.file_path
        )

        unless upload_result[:success]
          skipped_invalid += 1
          puts "Report ##{report.id} 迁移失败: #{upload_result[:error]}"
          next
        end

        data = upload_result[:data]
        report.update!(
          file_path: data[:file_path],
          file_size: data[:file_size],
          original_filename: data[:original_filename]
        )

        migrated += 1
      end
    rescue StandardError => e
      puts "Report ##{report.id} 迁移异常: #{e.class} - #{e.message}"
      skipped_invalid += 1
    end

    puts "迁移完成：成功 #{migrated} 条，缺失文件 #{skipped_missing} 条，异常/无效 #{skipped_invalid} 条。"
    puts "注意：旧目录 #{base_legacy_dir} 中的文件不会自动删除，请确认无误后再手工清理。"
  end
end
