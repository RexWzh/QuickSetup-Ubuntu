#!/bin/bash

DOWNLOAD_DIR=~/downloads

sudo apt install docker.io -y
## 下载 v2.22.0 版本
curl -L https://github.com/docker/compose/releases/download/v2.22.0/docker-compose-`uname -s`-`uname -m` -o $DOWNLOAD_DIR/docker-compose
## 赋予执行权限，并移动到系统目录
chmod +x $DOWNLOAD_DIR/docker-compose
sudo cp $DOWNLOAD_DIR/docker-compose /usr/bin/

# 将用户添加到 docker
sudo usermod -aG docker $USER

sudo mkdir -p /srv/docker
sudo chown :docker /srv/docker
sudo chmod 770 /srv/docker
sudo chmod +s /srv/docker