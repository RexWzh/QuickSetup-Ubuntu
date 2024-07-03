#!/bin/bash

# 创建下载目录
DOWNLOAD_DIR=~/downloads
mkdir -p $DOWNLOAD_DIR

# 安装 gdebi
if ! command -v gdebi &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y gdebi-core
fi

# 函数定义：下载并安装软件
install_software() {
    local url=$1
    local filename=$2

    if ! dpkg -l | grep -q "${filename%%_*}"; then
        wget -c "$url" -O "$DOWNLOAD_DIR/$filename"
        yes | sudo gdebi "$DOWNLOAD_DIR/$filename"
    else
        echo "$filename 已经安装"
    fi
}

# 安装 vscode
install_software "http://go.microsoft.com/fwlink/?LinkID=760868" "code.deb"

# 安装 Chrome 浏览器
install_software "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" "google-chrome-stable_current_amd64.deb"

# 安装 Linux QQ
install_software "https://dldir1.qq.com/qqfile/qq/QQNT/852276c1/linuxqq_3.2.5-21453_amd64.deb" "linuxqq_3.2.5-21453_amd64.deb"

# 安装 Linux WPS
install_software "https://wps-linux-personal.wpscdn.cn/wps/download/ep/Linux2019/11711/wps-office_11.1.0.11711_amd64.deb" "wps-office_11.1.0.11711_amd64.deb"