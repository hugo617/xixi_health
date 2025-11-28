Rails.application.routes.draw do
  get "reports/index"
  get "users/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "login" => "login#index"
  get "users" => "users#index"
  get "reports" => "reports#index"
  get "reports/:id/preview", to: "reports#preview", as: :report_preview
  get "reports/:id/download", to: "reports#download", as: :report_download

  # H5 移动端个人报告页面
  namespace :h5 do
    resources :users, only: [] do
      resource :profile, only: :show, controller: "profiles"
    end
  end
  
  # API路由配置
  namespace :api do
    namespace :v1 do
      # 用户搜索接口
      post 'users/search', to: 'users#search'
      # 用户创建接口
      post 'users/create', to: 'users#create'
      # 用户更新接口
      post 'users/update', to: 'users#update'
      # 用户删除接口
      post 'users/delete', to: 'users#delete'
      
      # 报告搜索接口
      post 'reports/search', to: 'reports#search'
      # 报告创建接口
      post 'reports/create', to: 'reports#create'
      # 报告更新接口
      post 'reports/update', to: 'reports#update'
      # 报告删除接口
      post 'reports/delete', to: 'reports#delete'
    end
  end
  
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"
end
