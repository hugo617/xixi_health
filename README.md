# xixi_health

# 初始化项目
rails new xixi_health -d mysql

# 创建数据库
rails db:create

# 创建页面模块
rails generate controller login index

rails generate controller users index

rails generate controller reports index