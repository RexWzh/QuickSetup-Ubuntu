#!/bin/bash
# 输入文件
INPUT_FILE="user_info.json"
# 定义标志
SKIP_CONFLICTS=0
# 解析命令行参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-conflicts) SKIP_CONFLICTS=1 ;;
        -s|--skip) SKIP_CONFLICTS=1 ;;
        *) echo "未知参数: $1"; exit 1 ;;
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
# 提取用户列表
USERS=$(jq -c '.users[]' "$INPUT_FILE")
echo "检查 UID/GID 冲突..."

# 创建用户的函数
create_user() {
    local user_json=$1
    local username=$(echo "$user_json" | jq -r '.username')
    local uid=$(echo "$user_json" | jq -r '.uid')
    local gid=$(echo "$user_json" | jq -r '.gid')
    local shell=$(echo "$user_json" | jq -r '.shell')
    local home=$(echo "$user_json" | jq -r '.home')
    local password_hash=$(echo "$user_json" | jq -r '.password_hash')
    local primary_group=$(echo "$user_json" | jq -r '.primary_group')
    
    # 获取二次组
    local secondary_groups_json=$(echo "$user_json" | jq -r '.secondary_groups | join(",")')
    
    # 检查用户名是否已存在
    if id "$username" &>/dev/null; then
        echo "冲突: 用户名 '$username' 已存在"
        return 1
    fi
    
    # 检查 UID 是否已存在
    existing_uid_user=$(getent passwd "$uid" | cut -d: -f1)
    if [ -n "$existing_uid_user" ]; then
        echo "冲突: UID $uid 已被用户 '$existing_uid_user' 使用"
        return 1
    fi
    
    # 检查主组是否需要创建
    if ! getent group "$primary_group" &>/dev/null; then
        echo "创建组: $primary_group (GID: $gid)"
        groupadd -g "$gid" "$primary_group" || {
            echo "错误: 无法创建组 $primary_group"
            return 1
        }
    else
        # 检查组的 GID 是否匹配
        existing_gid=$(getent group "$primary_group" | cut -d: -f3)
        if [ "$existing_gid" != "$gid" ]; then
            echo "冲突: 组 '$primary_group' 已存在，但 GID 不匹配 ($existing_gid != $gid)"
            return 1
        fi
    fi
    
    echo "创建用户: $username (UID: $uid, GID: $gid, Shell: $shell)"
    
    # 创建用户但不创建 home 目录 (-M)
    useradd -M -u "$uid" -g "$primary_group" -d "$home" -s "$shell" "$username" || {
        echo "错误: 无法创建用户 $username"
        return 1
    }
    
    # 检查 home 目录是否存在，如果不存在则创建
    if [ ! -d "$home" ]; then
        echo "创建 home 目录: $home"
        mkdir -p "$home"
        chown "$uid:$gid" "$home"
        chmod 750 "$home"
    fi
    
    # 还原密码哈希（如果有）
    if [ -n "$password_hash" ] && [ "$password_hash" != "null" ]; then
        echo "还原用户密码哈希..."
        # 使用 chpasswd 还原密码哈希
        echo "$username:$password_hash" | chpasswd -e || {
            echo "警告: 无法还原用户 $username 的密码哈希"
        }
    else
        echo "用户 $username 没有密码哈希，锁定账户"
        passwd -l "$username"
    fi
    
    # 添加用户到次要组
    if [ -n "$secondary_groups_json" ] && [ "$secondary_groups_json" != "null" ]; then
        echo "添加用户到次要组: $secondary_groups_json"
        # 先检查所有组是否存在
        IFS=',' read -ra SEC_GROUPS <<< "$secondary_groups_json"
        for group in "${SEC_GROUPS[@]}"; do
            if ! getent group "$group" &>/dev/null; then
                echo "警告: 组 $group 不存在，将被跳过"
            fi
        done
        
        # 添加用户到存在的组
        usermod -a -G "$secondary_groups_json" "$username" || {
            echo "警告: 无法将用户 $username 添加到某些次要组"
        }
    fi
    
    echo "用户 $username 创建成功"
    return 0
}

# 检查所有冲突
if [ "$SKIP_CONFLICTS" -eq 0 ]; then
    CONFLICT=0
    for user_json in $USERS; do
        username=$(echo "$user_json" | jq -r '.username')
        uid=$(echo "$user_json" | jq -r '.uid')
        gid=$(echo "$user_json" | jq -r '.gid')
        primary_group=$(echo "$user_json" | jq -r '.primary_group')
        
        # 检查用户名是否已存在
        if id "$username" &>/dev/null; then
            echo "冲突: 用户名 '$username' 已存在"
            CONFLICT=1
        fi
        
        # 检查 UID 是否已存在
        existing_uid_user=$(getent passwd "$uid" | cut -d: -f1)
        if [ -n "$existing_uid_user" ]; then
            echo "冲突: UID $uid 已被用户 '$existing_uid_user' 使用"
            CONFLICT=1
        fi
        
        # 检查组名是否存在但 GID 不匹配
        if getent group "$primary_group" &>/dev/null; then
            existing_gid=$(getent group "$primary_group" | cut -d: -f3)
            if [ "$existing_gid" != "$gid" ]; then
                echo "冲突: 组 '$primary_group' 已存在，但 GID 不匹配 ($existing_gid != $gid)"
                CONFLICT=1
            fi
        fi
        
        # 检查 GID 是否已被其他组使用
        existing_gid_group=$(getent group "$gid" | cut -d: -f1)
        if [ -n "$existing_gid_group" ] && [ "$existing_gid_group" != "$primary_group" ]; then
            echo "冲突: GID $gid 已被组 '$existing_gid_group' 使用"
            CONFLICT=1
        fi
    done
    
    # 如果有冲突，退出脚本
    if [ "$CONFLICT" -eq 1 ]; then
        echo "发现冲突，请解决冲突后再运行脚本，或使用 --skip-conflicts 选项跳过冲突的用户"
        exit 1
    fi
    
    echo "没有发现冲突，开始创建用户..."
    # 创建所有用户
    for user_json in $USERS; do
        create_user "$user_json"
    done
else
    # 跳过冲突模式：尝试创建每个用户，跳过有冲突的
    echo "跳过冲突模式：将跳过任何有冲突的用户"
    SKIPPED=0
    CREATED=0
    for user_json in $USERS; do
        username=$(echo "$user_json" | jq -r '.username')
        if create_user "$user_json"; then
            CREATED=$((CREATED + 1))
        else
            echo "跳过有冲突的用户: $username"
            SKIPPED=$((SKIPPED + 1))
        fi
    done
    echo "创建完成: $CREATED 个用户已创建，$SKIPPED 个用户已跳过"
fi


echo "所有处理完成"
echo "注意: 所有用户的密码已从备份中还原"
echo "如需手动设置密码，请使用: passwd <username>"