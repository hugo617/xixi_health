class ReportsController < ApplicationController
  # GET /reports
  # 报告列表页面
  def index
    # 页面初始化数据将通过JavaScript API调用加载
    # 这里可以添加任何页面级别的初始化逻辑
    @page_title = "健康报告管理"
  end
end
