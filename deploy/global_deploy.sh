#!/bin/bash

# 全球化部署脚本
set -e

echo "🌍 开始全球化部署..."

# 配置变量
APP_NAME="xixi-health-global"
DOCKER_REGISTRY="your-registry.com"  # 替换为你的Docker仓库
DOMAIN="xixi-health.com"              # 替换为你的域名
EMAIL="admin@xixi-health.com"         # 替换为你的邮箱

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 函数：输出状态信息
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 函数：检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 未安装，请先安装"
        exit 1
    fi
}

# 预部署检查
log_info "执行预部署检查..."
check_command docker
check_command docker-compose
check_command git

# 创建必要的目录
log_info "创建必要的目录结构..."
mkdir -p logs/{nginx,app,mysql,redis}
mkdir -p data/{mysql,redis}
mkdir -p ssl
mkdir -p backup

# 生成环境变量文件
log_info "生成环境变量配置..."
cat > .env.production << EOF
# 基础配置
RAILS_ENV=production_global
SECRET_KEY_BASE=$(openssl rand -hex 64)
RAILS_MASTER_KEY=$(openssl rand -hex 32)

# 数据库配置
DB_HOST=db
DB_PORT=3306
DB_NAME=xixi_health_production
DB_USERNAME=xixi_health
DB_PASSWORD=$(openssl rand -hex 16)
DB_ROOT_PASSWORD=$(openssl rand -hex 16)

# Redis配置
REDIS_URL=redis://redis:6379/0

# 邮件配置
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=$DOMAIN
SMTP_USERNAME=noreply@$DOMAIN
SMTP_PASSWORD=$(openssl rand -hex 16)

# 域名和主机配置
ASSET_HOST=https://cdn.$DOMAIN
ALLOWED_HOSTS=$DOMAIN,www.$DOMAIN,api.$DOMAIN,cdn.$DOMAIN

# 监控配置
GRAFANA_PASSWORD=$(openssl rand -hex 16)

# 时区和语言
DEFAULT_TIMEZONE=UTC
DEFAULT_LOCALE=en

# 安全配置
RAILS_LOG_LEVEL=info
RAILS_SERVE_STATIC_FILES=true
EOF

log_info "环境变量文件已生成：.env.production"

# 构建Docker镜像
log_info "构建Docker镜像..."
docker-compose -f docker-compose.global.yml build

# 推送镜像到仓库（如果有配置）
if [ ! -z "$DOCKER_REGISTRY" ]; then
    log_info "推送镜像到Docker仓库..."
    docker tag $APP_NAME:latest $DOCKER_REGISTRY/$APP_NAME:latest
    docker push $DOCKER_REGISTRY/$APP_NAME:latest
fi

# 数据库初始化
log_info "初始化数据库..."
docker-compose -f docker-compose.global.yml run --rm app bundle exec rails db:create db:migrate db:seed

# 生成SSL证书（使用Let's Encrypt）
log_info "生成SSL证书..."
if [ ! -f "ssl/cert.pem" ] || [ ! -f "ssl/key.pem" ]; then
    log_warn "正在生成自签名SSL证书，生产环境建议使用Let's Encrypt"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/key.pem \
        -out ssl/cert.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=*.$DOMAIN"
fi

# 启动服务
log_info "启动全球服务..."
docker-compose -f docker-compose.global.yml up -d

# 健康检查
log_info "执行健康检查..."
sleep 30

# 检查各服务状态
services=("nginx" "app" "db" "redis")
for service in "${services[@]}"; do
    if docker-compose -f docker-compose.global.yml ps | grep -q "$service.*Up"; then
        log_info "$service 服务运行正常"
    else
        log_error "$service 服务未正常运行"
        exit 1
    fi
done

# 测试应用响应
log_info "测试应用响应..."
if curl -f -k https://localhost/health > /dev/null 2>&1; then
    log_info "应用健康检查通过"
else
    log_error "应用健康检查失败"
    exit 1
fi

# 创建备份脚本
log_info "创建备份脚本..."
cat > backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backup/$DATE"
mkdir -p $BACKUP_DIR

# 数据库备份
docker-compose exec -T db mysqldump -u root -p$DB_ROOT_PASSWORD xixi_health_production > $BACKUP_DIR/database.sql

# 文件备份
tar -czf $BACKUP_DIR/storage.tar.gz data/

# 配置文件备份
tar -czf $BACKUP_DIR/config.tar.gz config/ docker-compose.global.yml .env.production

echo "备份完成：$BACKUP_DIR"
EOF
chmod +x backup.sh

# 创建监控脚本
log_info "创建监控脚本..."
cat > monitor.sh << 'EOF'
#!/bin/bash
# 监控脚本

echo "=== 系统状态监控 ==="
echo "Docker容器状态："
docker-compose -f docker-compose.global.yml ps

echo ""
echo "系统资源使用："
docker stats --no-stream

echo ""
echo "磁盘空间："
df -h

echo ""
echo "内存使用："
free -h

echo ""
echo "网络连接："
netstat -tuln | grep -E ':(3000|3306|6379|80|443)' | head -10
EOF
chmod +x monitor.sh

# 部署完成
log_info "🎉 全球化部署完成！"
log_info "访问地址："
log_info "- 主应用：https://localhost (需要配置域名)"
log_info "- 监控面板：http://localhost:3001 (Grafana)"
log_info "- Prometheus：http://localhost:9090"
log_info ""
log_info "下一步："
log_info "1. 配置域名解析到服务器IP"
log_info "2. 获取有效的SSL证书(Let's Encrypt)"
log_info "3. 配置CDN加速"
log_info "4. 设置防火墙规则"
log_info "5. 配置自动备份"
log_info "6. 部署到多个地域"

echo ""
echo "📋 部署摘要："
echo "- 应用容器：4个实例(负载均衡)"
echo "- 数据库：MySQL 8.0 主从配置"
echo "- 缓存：Redis 7 集群"
echo "- 反向代理：Nginx + SSL"
echo "- 监控：Prometheus + Grafana"
echo "- 日志：集中式日志收集"
echo "- 备份：自动化备份脚本"