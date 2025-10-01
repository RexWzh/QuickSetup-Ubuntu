#!/bin/bash

# 检查是否为 Ubuntu 系统
if ! command -v lsb_release &> /dev/null; then
    echo "错误: lsb_release 命令未找到，请确保在 Ubuntu 系统上运行此脚本"
    exit 1
fi

# 检查是否为 Ubuntu 发行版
DISTRIB_ID=$(lsb_release -si)
if [ "$DISTRIB_ID" != "Ubuntu" ]; then
    echo "错误: 此脚本仅支持 Ubuntu 系统，当前系统: $DISTRIB_ID"
    exit 1
fi

# 获取 Ubuntu 版本代号
CODENAME=$(lsb_release -sc)
VERSION=$(lsb_release -sr)

echo "检测到 Ubuntu $VERSION ($CODENAME)"

# Ubuntu LTS 版本映射
declare -A LTS_VERSIONS=(
    ["16.04"]="xenial"
    ["18.04"]="bionic"
    ["20.04"]="focal"
    ["22.04"]="jammy"
    ["24.04"]="noble"
)

# 检查是否为支持的 LTS 版本
if [[ -n "${LTS_VERSIONS[$VERSION]}" ]]; then
    CODENAME="${LTS_VERSIONS[$VERSION]}"
    echo "使用 LTS 版本 $VERSION 的源配置 ($CODENAME)"
elif [[ "$CODENAME" =~ ^(xenial|bionic|focal|jammy|noble)$ ]]; then
    echo "使用检测到的代号: $CODENAME"
else
    echo "警告: 未知的 Ubuntu 版本 $VERSION ($CODENAME)"
    echo "尝试使用检测到的代号，如果遇到问题请手动配置"
fi

# 备份原始 sources.list
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
echo "已备份原始 sources.list 到 /etc/apt/sources.list.backup"

# 生成新的 sources.list
echo "正在配置 Ubuntu $VERSION ($CODENAME) 的清华大学镜像源..."

sudo cat > /etc/apt/sources.list <<EOF
# Ubuntu $VERSION ($CODENAME) 清华大学镜像源
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME main restricted universe multiverse

deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME-updates main restricted universe multiverse

deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME-backports main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu/ $CODENAME-security main restricted universe multiverse
# deb-src http://security.ubuntu.com/ubuntu/ $CODENAME-security main restricted universe multiverse

# 预发布软件源（默认注释）
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME-proposed main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME-proposed main restricted universe multiverse
EOF

echo "源配置完成！"

# 可选：移除可能无法访问的第三方源
if [ -f /etc/apt/sources.list.d/google-chrome.list ]; then
    echo "备份 Google Chrome 源配置..."
    sudo mv /etc/apt/sources.list.d/google-chrome.list /etc/apt/sources.list.d/google-chrome.list.backup
fi

# 更新软件包列表
echo "正在更新软件包列表..."
if sudo apt update; then
    echo "软件源配置成功！"
else
    echo "错误: 更新软件包列表失败，正在恢复原始配置..."
    sudo cp /etc/apt/sources.list.backup /etc/apt/sources.list
    echo "已恢复原始 sources.list 配置"
    exit 1
fi