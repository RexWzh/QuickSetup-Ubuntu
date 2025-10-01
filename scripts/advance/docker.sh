#!/bin/bash

DOWNLOAD_DIR=~/downloads

# 检查 Docker 是否已安装
if command -v docker &> /dev/null; then
    echo "Docker 已安装，版本: $(docker --version)"
else
    echo "正在安装 Docker..."
    sudo apt install docker.io -y
    echo "Docker 安装完成"
fi

# 检查 Docker Compose 是否已安装
if command -v docker-compose &> /dev/null; then
    echo "Docker Compose 已安装，版本: $(docker-compose --version)"
else
    echo "正在安装 Docker Compose..."
    
    # 创建下载目录
    mkdir -p $DOWNLOAD_DIR
    
    ## 下载 v2.22.0 版本
    curl -L https://github.com/docker/compose/releases/download/v2.22.0/docker-compose-`uname -s`-`uname -m` -o $DOWNLOAD_DIR/docker-compose
    
    ## 赋予执行权限，并移动到系统目录
    chmod +x $DOWNLOAD_DIR/docker-compose
    sudo cp $DOWNLOAD_DIR/docker-compose /usr/bin/
    
    echo "Docker Compose 安装完成"
fi

# 检查当前用户是否已在 docker 组中
if groups $USER | grep -q '\bdocker\b'; then
    echo "用户 $USER 已在 docker 组中"
else
    echo "将用户 $USER 添加到 docker 组..."
    # 将用户添加到 docker
    sudo usermod -aG docker $USER
    echo "用户已添加到 docker 组，请重新登录或重启以生效"
fi

# 检查 /srv/docker 目录是否已存在并配置正确
if [ -d "/srv/docker" ]; then
    echo "/srv/docker 目录已存在"
    # 检查权限是否正确
    CURRENT_PERMS=$(stat -c "%a" /srv/docker 2>/dev/null)
    if [ "$CURRENT_PERMS" != "2770" ]; then
        echo "正在修正 /srv/docker 目录权限..."
        sudo chown :docker /srv/docker
        sudo chmod 770 /srv/docker
        sudo chmod +s /srv/docker
    fi
else
    echo "创建并配置 /srv/docker 目录..."
    sudo mkdir -p /srv/docker
    sudo chown :docker /srv/docker
    sudo chmod 770 /srv/docker
    sudo chmod +s /srv/docker
fi

echo "Docker 环境配置完成！"