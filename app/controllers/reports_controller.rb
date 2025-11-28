class ReportsController < ApplicationController
  # GET /reports
  # 报告列表页面
  def index
    # 页面初始化数据将通过JavaScript API调用加载
    # 这里可以添加任何页面级别的初始化逻辑
    @page_title = "健康报告管理"
  end

  # GET /reports/:id/preview
  # 报告PDF预览页面
  def preview
    result = Reports::FileService.call(report_id: params[:id])

    if result[:success]
      @report = result[:data][:report]
      @file_url = result[:data][:relative_url]
      @error_message = nil
      render :preview
    else
      @report = nil
      @file_url = nil
      @error_message = result[:error] || "无法加载报告文件"
      Rails.logger.warn "ReportsController#preview error: #{@error_message}"
      render :preview, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "ReportsController#preview unexpected error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @report = nil
    @file_url = nil
    @error_message = "预览报告失败，请稍后重试"
    render :preview, status: :internal_server_error
  end

  # GET /reports/:id/download
  # 报告PDF下载
  def download
    result = Reports::FileService.call(report_id: params[:id])

    if result[:success]
      data = result[:data]
      send_file(
        data[:file_path],
        filename: data[:filename],
        type: data[:content_type],
        disposition: "attachment"
      )
    else
      @report = nil
      @file_url = nil
      @error_message = result[:error] || "无法下载报告文件"
      Rails.logger.warn "ReportsController#download error: #{@error_message}"
      render :preview, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "ReportsController#download unexpected error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @report = nil
    @file_url = nil
    @error_message = "下载报告失败，请稍后重试"
    render :preview, status: :internal_server_error
  end
end
