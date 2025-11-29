# 🚂 Railway 部署指南

## 一键部署到 Railway（全球访问）

### 🎯 目标
- ✅ 获得全球可访问的链接
- ✅ 支持手机访问
- ✅ 自动SSL证书
- ✅ 免费托管

## 🚀 快速部署步骤

### 1. 准备代码
```bash
# 确保代码已提交
git add .
git commit -m "Ready for Railway deployment"
```

### 2. 部署到 Railway

#### 方法一：GitHub 集成（推荐）
1. **Fork 你的代码到 GitHub**
2. **访问 Railway**: https://railway.app
3. **点击 "Deploy from GitHub"**
4. **选择你的仓库**
5. **自动部署完成**

#### 方法二：CLI 部署
```bash
# 安装 Railway CLI
curl -fsSL https://railway.app/install.sh | sh

# 登录 Railway
railway login

# 初始化项目
railway init

# 部署
railway up
```

### 3. 环境变量配置
在 Railway 控制台设置这些环境变量：

```env
RAILS_ENV=railway
RAILS_SERVE_STATIC_FILES=true
SECRET_KEY_BASE=your-secret-key-here
RAILS_MASTER_KEY=your-master-key-here
DATABASE_URL=your-database-url
REDIS_URL=your-redis-url
RAILS_LOG_LEVEL=info
```

## 🌍 获得访问链接

部署完成后，Railway 会提供：

**🔗 全球访问链接**: `https://your-app-name.railway.app`

**📱 手机访问**: 直接点击链接或扫码访问

## 🎯 测试路由

部署成功后，你可以访问：

- **首页**: `https://your-app-name.railway.app`
- **用户列表**: `https://your-app-name.railway.app/users`
- **报告列表**: `https://your-app-name.railway.app/reports`
- **健康检查**: `https://your-app-name.railway.app/health`

## 📊 Railway 免费额度

| 资源 | 免费额度 | 说明 |
|------|----------|------|
| **CPU** | 500 hours/月 | 足够小型应用 |
| **内存** | 1GB | 共享内存 |
| **存储** | 5GB | 数据库+文件 |
| **带宽** | 100GB/月 | 全球CDN |

## 🔧 高级配置

### 自定义域名
1. 在 Railway 控制台添加自定义域名
2. 配置 DNS CNAME 记录
3. 自动 SSL 证书

### 数据库升级
```bash
# 升级到 PostgreSQL 专业版
railway add --database
```

### 环境变量管理
```bash
# 设置环境变量
railway variables set RAILS_ENV=production
railway variables set SECRET_KEY_BASE=your-secret
```

## 🆘 常见问题

### 部署失败
- 检查 Dockerfile 语法
- 确认所有依赖都在 Gemfile
- 查看 Railway 控制台日志

### 数据库连接失败
- 确认 DATABASE_URL 格式正确
- 检查数据库服务状态
- 验证网络连接

### 访问超时
- 检查应用启动日志
- 确认健康检查端点正常
- 查看 Railway 服务状态

## 📱 手机访问测试

部署完成后，用手机测试：
1. 打开浏览器
2. 输入 Railway 提供的链接
3. 测试所有功能

## 🎉 完成

恭喜你！现在你的应用有了全球可访问的链接，任何人都可以通过手机访问了！

**下一步**: 分享你的链接给朋友们测试吧！