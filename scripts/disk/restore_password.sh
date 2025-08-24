#!/bin/bash
# 批量还原用户密码脚本
# 用法: ./restore_passwords.sh [--force] [输入文件]

# 默认输入文件
INPUT_FILE="user_info.json"
FORCE_MODE=0

# 解析命令行参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --force|-f) FORCE_MODE=1 ;;
        -*) echo "未知选项: $1"; exit 1 ;;
        *) INPUT_FILE="$1" ;;
    esac
    shift
done

# 检查是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "错误: 需要 root 权限运行此脚本"
    exit 1
fi

# 检查输入文件是否存在
if [ ! -f "$INPUT_FILE" ]; then
    echo "错误: 输入文件 $INPUT_FILE 不存在"
    exit 1
fi

# 检查 jq 是否安装
if ! command -v jq &> /dev/null; then
    echo "错误: 此脚本需要 jq 工具。请运行: apt-get install jq"
    exit 1
fi

# 临时文件，用于存储密码信息
TEMP_PASSWD_FILE=$(mktemp)
trap "rm -f $TEMP_PASSWD_FILE" EXIT

echo "开始还原用户密码..."

# 提取用户列表
USERS=$(jq -c '.users[]' "$INPUT_FILE" 2>/dev/null || jq -c '.[]' "$INPUT_FILE")

# 统计计数器
RESTORED=0
SKIPPED=0
FAILED=0

# 处理每个用户
for user_json in $USERS; do
    username=$(echo "$user_json" | jq -r '.username')
    password_hash=$(echo "$user_json" | jq -r '.password_hash')
    
    # 检查用户是否存在
    if ! id "$username" &>/dev/null; then
        echo "跳过: 用户 '$username' 不存在"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    # 检查密码哈希是否可用
    if [ -z "$password_hash" ] || [ "$password_hash" = "null" ]; then
        echo "跳过: 用户 '$username' 没有密码哈希"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    echo "处理用户: $username"
    
    # 将用户名和密码哈希写入临时文件
    echo "$username:$password_hash" >> "$TEMP_PASSWD_FILE"
    
    RESTORED=$((RESTORED + 1))
done

# 一次性应用所有密码
if [ "$RESTORED" -gt 0 ]; then
    echo "正在应用 $RESTORED 个用户的密码..."
    
    if chpasswd -e < "$TEMP_PASSWD_FILE"; then
        echo "成功还原 $RESTORED 个用户的密码"
    else
        echo "错误: 密码还原失败"
        FAILED=$RESTORED
        RESTORED=0
    fi
else
    echo "没有用户需要还原密码"
fi

# 显示结果
echo ""
echo "密码还原完成"
echo "-----------------"
echo "还原成功: $RESTORED"
echo "已跳过: $SKIPPED"
echo "还原失败: $FAILED"
echo "-----------------"

if [ "$FORCE_MODE" -eq 1 ]; then
    echo "注意: 强制模式已启用，可能覆盖了现有密码"
fi

echo ""
echo "如需手动设置密码，请使用: passwd <username>"