#!/bin/bash

# 配置文件路径
SSHD_CONFIG='/etc/ssh/sshd_config'

# 设置端口号为22
# sudo sed -i 's/^#Port [0-9]*/Port 22/' $SSHD_CONFIG

# 禁止 root 用户登录
# sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' $SSHD_CONFIG

# 禁止密码登录
# sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/'$SSHD_CONFIG

# 重启 SSH 服务
# sudo systemctl restart ssh
