#!/bin/bash

# 更新软件包源列表
sudo apt update
# 基础工具
sudo apt install vim git nginx curl tmux zsh tree pwgen -y
sudo apt install ncdu -y # 磁盘占用查看工具
sudo apt install smem -y # 内存占用查看工具

# 编译相关
sudo apt install make gcc flex bison -y

# Json 解析工具
sudo apt install jq -y

# Apache HTTP 工具 | 比如 htpasswd 命令
sudo apt install apache2-utils -y

# net-tools 工具包，比如 ifconfig 等命令
sudo apt install net-tools -y

# deb 安装工具
sudo apt install gdebi -y

# Java 运行环境
sudo apt install openjdk-11-jdk -y

# 文档转化工具 doc2txt, pdf2txt
sudo apt install antiword poppler-utils -y

# 安装 ssh 服务器
sudo apt install openssh-server -y

# 安装剪贴板命令
sudo apt install xclip -y

# 安装 ffmpeg
sudo apt install ffmpeg -y

# 安装硬盘管理工具
sudo apt install testdisk network-manager gddrescue lvm2 sshfs smartmontools gparted -y
