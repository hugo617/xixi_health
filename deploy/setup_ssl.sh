#!/bin/bash

# SSL证书配置脚本 - 支持Let's Encrypt
set -e

DOMAIN=${1:-"xixi-health.com"}
EMAIL=${2:-"admin@xixi-health.com"}

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔐 设置SSL证书...${NC}"

# 创建SSL目录
mkdir -p ssl

# 方法1: 使用Let's Encrypt (生产环境推荐)
setup_letsencrypt() {
    echo -e "${GREEN}使用Let's Encrypt获取SSL证书${NC}"
    
    # 安装Certbot
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y certbot
    elif command -v yum &> /dev/null; then
        sudo yum install -y certbot
    else
        echo -e "${YELLOW}请手动安装Certbot${NC}"
        return 1
    fi
    
    # 获取证书
    sudo certbot certonly --standalone \
        -d $DOMAIN \
        -d www.$DOMAIN \
        --email $EMAIL \
        --agree-tos \
        --non-interactive
    
    # 复制证书到项目目录
    sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/cert.pem
    sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/key.pem
    sudo chmod 644 ssl/cert.pem
    sudo chmod 600 ssl/key.pem
    
    echo -e "${GREEN}Let's Encrypt证书获取成功！${NC}"
}

# 方法2: 自签名证书 (开发/测试环境)
setup_self_signed() {
    echo -e "${GREEN}生成自签名SSL证书${NC}"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/key.pem \
        -out ssl/cert.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"
    
    chmod 600 ssl/key.pem
    chmod 644 ssl/cert.pem
    
    echo -e "${YELLOW}自签名证书生成成功！(仅适用于开发环境)${NC}"
}

# 方法3: 使用CloudFlare Origin证书
setup_cloudflare() {
    echo -e "${GREEN}CloudFlare Origin证书配置${NC}"
    echo -e "${YELLOW}请按照以下步骤操作：${NC}"
    echo "1. 登录CloudFlare控制台"
    echo "2. 进入SSL/TLS -> Origin Server"
    echo "3. 创建Origin证书"
    echo "4. 下载证书和私钥"
    echo "5. 保存为 ssl/cert.pem 和 ssl/key.pem"
}

# 自动续期脚本
create_renewal_script() {
    cat > renew_ssl.sh << 'EOF'
#!/bin/bash
# SSL证书续期脚本

echo "开始续期SSL证书..."

# Let's Encrypt续期
sudo certbot renew --quiet

# 复制新证书
sudo cp /etc/letsencrypt/live/DOMAIN/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/DOMAIN/privkey.pem ssl/key.pem

# 重启Nginx
docker-compose -f docker-compose.global.yml restart nginx

echo "SSL证书续期完成！"
EOF
    chmod +x renew_ssl.sh
}

# 显示菜单
echo "请选择SSL证书获取方式："
echo "1) Let's Encrypt (推荐 - 生产环境)"
echo "2) 自签名证书 (开发/测试环境)"
echo "3) CloudFlare Origin证书"
echo "4) 手动配置已有证书"

read -p "请输入选项 (1-4): " choice

case $choice in
    1)
        setup_letsencrypt
        create_renewal_script
        ;;
    2)
        setup_self_signed
        ;;
    3)
        setup_cloudflare
        ;;
    4)
        echo -e "${YELLOW}请将证书文件放置到 ssl/ 目录：${NC}"
        echo "- ssl/cert.pem (证书)"
        echo "- ssl/key.pem (私钥)"
        ;;
    *)
        echo -e "${YELLOW}无效选项，退出...${NC}"
        exit 1
        ;;
esac

# 验证证书
echo -e "${GREEN}验证SSL证书...${NC}"
if [ -f "ssl/cert.pem" ] && [ -f "ssl/key.pem" ]; then
    openssl x509 -in ssl/cert.pem -text -noout | grep -A1 "Subject:"
    echo -e "${GREEN}SSL证书配置成功！${NC}"
else
    echo -e "${YELLOW}SSL证书文件未找到${NC}"
fi

# 添加到crontab（Let's Encrypt续期）
if [ $choice -eq 1 ]; then
    echo -e "${GREEN}设置自动续期...${NC}"
    (crontab -l 2>/dev/null; echo "0 2 * * * $(pwd)/renew_ssl.sh") | crontab -
    echo -e "${GREEN}自动续期已设置（每天凌晨2点）${NC}"
fi

echo -e "${GREEN}🔐 SSL证书配置完成！${NC}"