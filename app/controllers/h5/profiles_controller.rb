module H5
  class ProfilesController < ApplicationController
    # GET /h5/users/:user_id/profile
    # 移动端个人报告主页
    def show
      @user = User.not_deleted.find_by(id: params[:user_id])

      if @user.nil?
        @error_message = "用户不存在或已被删除"
        Rails.logger.warn "H5::ProfilesController#show - user not found: #{params[:user_id]}"
      else
        @error_message = nil
      end
    rescue StandardError => e
      Rails.logger.error "H5::ProfilesController#show error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @user = nil
      @error_message = "加载用户信息失败，请稍后重试"
    end
  end
end

