class ApplicationController < ActionController::Base
  helper_method :show_sidenav?  
  def show_sidenav?
  # 只在特定的控制器和动作中显示侧边栏
  (controller_name == 'users' && action_name == 'index') ||
  (controller_name == 'reports' && action_name.in?(%w[index]))
  end
  
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end