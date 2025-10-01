#!/bin/bash

echo "正在配置 Docker..."

# 创建 Docker 配置目录
sudo mkdir -p /etc/docker

# 检查 /etc/docker/daemon.json 是否存在
if [ ! -f /etc/docker/daemon.json ]; then
    echo "创建 Docker daemon 配置文件..."
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "default-address-pools":
  [
    {"base":"100.10.0.0/16","size":24}
  ]
}
EOF
    echo "已创建 /etc/docker/daemon.json"
else
    echo "/etc/docker/daemon.json 已存在，跳过创建"
fi

# 创建 systemd 服务目录
sudo mkdir -p /etc/systemd/system/docker.service.d

# 检查代理配置文件是否存在
PROXY_CONF="/etc/systemd/system/docker.service.d/http-proxy.conf"
if [ ! -f "$PROXY_CONF" ]; then
    echo "创建 Docker 代理配置文件..."
    sudo tee "$PROXY_CONF" > /dev/null <<EOF
[Service]
# Environment="HTTP_PROXY="
# Environment="HTTPS_PROXY="
# Environment="NO_PROXY=localhost,127.0.0.1"
EOF
    echo "已创建 $PROXY_CONF"
else
    echo "$PROXY_CONF 已存在，跳过创建"
fi

# 重新加载 systemd 配置
echo "重新加载 systemd 配置..."
sudo systemctl daemon-reload

# 检查 Docker 服务状态并重启（如果正在运行）
if systemctl is-active --quiet docker; then
    echo "重启 Docker 服务以应用配置..."
    sudo systemctl restart docker
    echo "Docker 服务已重启"
else
    echo "Docker 服务未运行，配置将在下次启动时生效"
fi

echo "Docker 配置完成！"
echo ""
echo "配置说明："
echo "1. daemon.json: 配置了自定义地址池 100.10.0.0/16"
echo "2. http-proxy.conf: 代理配置模板（默认注释状态）"
echo ""
echo "如需启用代理，请编辑 $PROXY_CONF 文件，取消相关行的注释并设置代理地址"