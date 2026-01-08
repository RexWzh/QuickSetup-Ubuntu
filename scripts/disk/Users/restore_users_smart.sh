#!/bin/bash

# ==============================================================================
# 脚本名称: restore_users_smart.sh
# 功能描述: 智能还原用户和组设置（修改现有用户而非删除重建）
# 使用方法: sudo ./restore_users_smart.sh <users_backup.json>
# 依赖项: jq
# ==============================================================================

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请以 root 权限运行此脚本"
    exit 1
fi

# 检查参数
if [ $# -ne 1 ]; then
    echo "用法: $0 <users_backup.json>"
    exit 1
fi

INPUT_FILE="$1"

# 检查输入文件是否存在
if [ ! -f "$INPUT_FILE" ]; then
    echo "错误: 文件 '$INPUT_FILE' 不存在"
    exit 1
fi

# 检查 jq 是否安装
if ! command -v jq &>/dev/null; then
    echo "错误: 未找到 jq 命令。请先安装 jq (apt install jq)"
    exit 1
fi

echo "正在读取用户配置文件: $INPUT_FILE"

# ==============================================================================
# 函数: 处理组 (Create or Update)
# ==============================================================================
ensure_group() {
    local group_json=$1
    # 提取字段
    local group_name=$(echo "$group_json" | jq -r '.group_name')
    local target_gid=$(echo "$group_json" | jq -r '.gid')

    if [ -z "$group_name" ] || [ "$group_name" == "null" ]; then
         # 尝试兼容旧格式或不同字段名
         return 0
    fi
    
    # 1. 检查组是否存在
    if getent group "$group_name" &>/dev/null; then
        current_gid=$(getent group "$group_name" | cut -d: -f3)
        
        if [ "$current_gid" == "$target_gid" ]; then
            echo "[OK] 组 '$group_name' 已存在且 GID ($current_gid) 匹配"
            return 0
        else
            echo "[UPDATE] 组 '$group_name' 存在但 GID 不匹配 ($current_gid -> $target_gid)"
            
            # 检查目标 GID 是否被占用
            if getent group "$target_gid" &>/dev/null; then
                occupier=$(getent group "$target_gid" | cut -d: -f1)
                echo "  错误: 目标 GID $target_gid 已被组 '$occupier' 占用，跳过修改"
                return 1
            fi
            
            # 修改 GID
            groupmod -g "$target_gid" "$group_name"
            echo "  已更新组 '$group_name' 的 GID 为 $target_gid"
        fi
    else
        # 2. 组不存在，检查目标 GID 是否被占用
        if getent group "$target_gid" &>/dev/null; then
            occupier=$(getent group "$target_gid" | cut -d: -f1)
            echo "[ERROR] 无法创建组 '$group_name'，因为 GID $target_gid 已被 '$occupier' 占用"
            return 1
        fi

        echo "[CREATE] 创建组 '$group_name' (GID: $target_gid)"
        groupadd -g "$target_gid" "$group_name"
    fi
}

# ==============================================================================
# 函数: 辅助处理用户的主组 (Ensure Primary Group Exists)
# ==============================================================================
ensure_primary_group() {
    local group_name=$1
    local target_gid=$2
    # 简化的组检查，主要用于确保用户创建前组已存在
    if ! getent group "$group_name" &>/dev/null; then
        if getent group "$target_gid" &>/dev/null; then
            echo "  错误: 无法创建主组 '$group_name' (GID $target_gid 已占用)"
            return 1
        fi
        groupadd -g "$target_gid" "$group_name"
        echo "  已创建主组 '$group_name'"
    fi
}

# ==============================================================================
# 函数: 处理用户 (Create or Update)
# ==============================================================================
ensure_user() {
    local user_json=$1
    local username=$(echo "$user_json" | jq -r '.username')
    local target_uid=$(echo "$user_json" | jq -r '.uid')
    local target_gid=$(echo "$user_json" | jq -r '.gid')
    local shell=$(echo "$user_json" | jq -r '.shell')
    local home=$(echo "$user_json" | jq -r '.home')
    local password_hash=$(echo "$user_json" | jq -r '.password_hash')
    local primary_group=$(echo "$user_json" | jq -r '.primary_group')
    local secondary_groups_json=$(echo "$user_json" | jq -r '.secondary_groups | join(",")')

    echo "----------------------------------------------------------------"
    echo "处理用户: $username (目标 UID: $target_uid)"

    # 1. 确保主组就绪
    # 注意：JSONL 中 Group 记录应该在 User 之前。
    # 这里再次检查是为了防止 User 记录先于 Group 记录出现，或者 User 使用了未导出的组
    ensure_primary_group "$primary_group" "$target_gid"
    
    # 2. 检查用户是否存在
    if id "$username" &>/dev/null; then
        current_uid=$(id -u "$username")
        current_gid=$(id -g "$username")
        
        # 检查 UID 是否需要修改
        if [ "$current_uid" != "$target_uid" ]; then
            echo "  [UPDATE] UID 不匹配 ($current_uid -> $target_uid)"
            
            # 检查目标 UID 占用
            if getent passwd "$target_uid" &>/dev/null; then
                occupier=$(getent passwd "$target_uid" | cut -d: -f1)
                echo "  错误: 目标 UID $target_uid 已被用户 '$occupier' 占用，跳过修改"
                return 1
            fi

            # 修改 UID (自动修复 home 目录归属)
            usermod -u "$target_uid" "$username"
            echo "  已更新 UID (Home 目录权限已自动修正)"
        else
            echo "  [OK] UID 匹配"
        fi

        # 检查主组是否需要修改
        if [ "$current_gid" != "$target_gid" ]; then
             echo "  [UPDATE] 主组 GID 不匹配 ($current_gid -> $target_gid)"
             usermod -g "$target_gid" "$username"
             echo "  已更新主组"
        fi
        
        # 确保 Shell 和 Home 设置正确
        usermod -s "$shell" -d "$home" "$username"

    else
        # 3. 用户不存在，创建新用户
        echo "  [CREATE] 创建用户 $username"
        
        # 检查目标 UID 占用
        if getent passwd "$target_uid" &>/dev/null; then
            occupier=$(getent passwd "$target_uid" | cut -d: -f1)
            echo "  错误: 目标 UID $target_uid 已被用户 '$occupier' 占用，无法创建"
            return 1
        fi

        useradd -M -u "$target_uid" -g "$target_gid" -d "$home" -s "$shell" "$username"
        
        # 创建 Home (如果不存在)
        if [ ! -d "$home" ]; then
            mkdir -p "$home"
            chown "$target_uid:$target_gid" "$home"
            chmod 750 "$home"
            echo "  已创建 Home 目录"
        fi
    fi

    # 4. 还原密码
    if [ -n "$password_hash" ] && [ "$password_hash" != "null" ]; then
        # 仅当哈希值不同时才更新（为了安全，直接覆盖）
        echo "$username:$password_hash" | chpasswd -e
        echo "  已同步密码"
    fi

    # 5. 处理附加组
    if [ -n "$secondary_groups_json" ] && [ "$secondary_groups_json" != "null" ]; then
        usermod -G "$secondary_groups_json" "$username"
        echo "  已同步附加组: $secondary_groups_json"
    fi
}

# ==============================================================================
# 主循环 (JSONL 处理)
# ==============================================================================

while IFS= read -r line; do
    # 跳过空行
    [ -z "$line" ] && continue
    
    # 获取类型
    type=$(echo "$line" | jq -r '.type')
    
    if [ "$type" == "group" ]; then
        ensure_group "$line"
    elif [ "$type" == "user" ]; then
        ensure_user "$line"
    else
        echo "未知记录类型: $type (跳过)"
    fi
done < "$INPUT_FILE"

echo "----------------------------------------------------------------"
echo "完成。请检查上方日志是否有错误信息。"
