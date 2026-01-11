#!/bin/bash
# Docker 镜像源配置修复脚本

set -e

echo "检查并修复 Docker 镜像源配置..."

# 检查 daemon.json 是否存在
if [ ! -f /etc/docker/daemon.json ]; then
    echo "创建 /etc/docker/daemon.json..."
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "registry-mirrors": [
    "https://mirror.baidubce.com",
    "https://hub-mirror.c.163.com"
  ],
  "dns": ["8.8.8.8", "8.8.4.4"]
}
EOF
    echo "✓ 配置已创建"
else
    echo "✓ daemon.json 已存在"
    cat /etc/docker/daemon.json
fi

echo ""
echo "重启 Docker 服务..."
sudo systemctl restart docker

echo ""
echo "等待 Docker 启动..."
sleep 3

echo ""
echo "✓ Docker 镜像源配置完成"
echo ""
echo "已配置的镜像源："
echo "  - mirror.baidubce.com（百度）"
echo "  - hub-mirror.c.163.com（网易）"
echo ""
echo "下一步："
echo "  docker compose build realtime"
