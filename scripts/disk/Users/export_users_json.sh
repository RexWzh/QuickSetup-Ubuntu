#!/bin/bash

# 输出 JSONL 文件
OUTPUT_FILE="users_info.jsonl"

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "警告: 未以 root 身份运行。无法读取 /etc/shadow 中的密码哈希。"
    echo "建议使用 sudo 运行此脚本以获取完整信息。"
fi

# 定义源文件
PASSWD_FILE="/etc/passwd"
GROUP_FILE="/etc/group"
SHADOW_FILE="/etc/shadow"

echo "正在导出用户和组信息到 $OUTPUT_FILE (JSONL格式)..."

# 清空输出文件
> "$OUTPUT_FILE"

# ==============================================================================
# 1. 导出组 (GID >= 1000)
# ==============================================================================
while IFS=: read -r group_name _ group_id members; do
    if [ "$group_id" -ge 1000 ] && [ "$group_id" -ne 65534 ]; then
        
        # 处理组成员
        member_json_str="[]"
        if [ -n "$members" ]; then
            member_json_arr=()
            IFS=',' read -ra member_array <<< "$members"
            for member in "${member_array[@]}"; do
                member_json_arr+=("\"$member\"")
            done
            if [ ${#member_json_arr[@]} -gt 0 ]; then
                member_json_str="[$(IFS=,; echo "${member_json_arr[*]}")]"
            fi
        fi

        # 输出 Group JSONL
        echo "{\"type\":\"group\", \"group_name\":\"$group_name\", \"gid\":$group_id, \"members\":$member_json_str}" >> "$OUTPUT_FILE"
    fi
done < "$GROUP_FILE"

# ==============================================================================
# 2. 导出用户 (UID >= 1000)
# ==============================================================================
# 排除 nobody (65534)
while IFS=: read -r username password uid gid gecos home shell; do
    if [ "$uid" -ge 1000 ] && [ "$uid" -ne 65534 ]; then
        
        # 简单转义 gecos 中的双引号
        gecos_escaped=${gecos//\"/\\\"}

        # 获取密码哈希 (如果可读)
        passwd_hash=""
        if [ -r "$SHADOW_FILE" ]; then
            # 使用 grep 精确匹配用户名
            hash_line=$(grep "^$username:" "$SHADOW_FILE" 2>/dev/null)
            if [ -n "$hash_line" ]; then
                passwd_hash=$(echo "$hash_line" | cut -d: -f2)
            fi
        fi

        # 获取主组名称
        primary_group=$(grep "^[^:]*:x:$gid:" "$GROUP_FILE" | head -1 | cut -d: -f1)
        
        # 获取附加组
        secondary_groups=()
        while IFS=: read -r group_name _ group_id members; do
            if [[ ",$members," == *",$username,"* ]] && [ "$group_id" != "$gid" ]; then
                secondary_groups+=("\"$group_name\"")
            fi
        done < "$GROUP_FILE"
        
        sec_groups_json="[]"
        if [ ${#secondary_groups[@]} -gt 0 ]; then
            sec_groups_json="[$(IFS=,; echo "${secondary_groups[*]}")]"
        fi
        
        # 构建 User JSON 对象
        json_line="{\"type\":\"user\", \"username\": \"$username\", \"uid\": $uid, \"gid\": $gid, \"gecos\": \"$gecos_escaped\", \"home\": \"$home\", \"shell\": \"$shell\", \"primary_group\": \"$primary_group\", \"secondary_groups\": $sec_groups_json"
        
        if [ -n "$passwd_hash" ]; then
            json_line="$json_line, \"password_hash\": \"$passwd_hash\""
        fi
        
        json_line="$json_line}"
        
        echo "$json_line" >> "$OUTPUT_FILE"
    fi
done < "$PASSWD_FILE"

echo "导出完成: $OUTPUT_FILE"

# 验证 JSON (如果安装了 jq)
if command -v jq &> /dev/null; then
    if jq empty "$OUTPUT_FILE" 2>/dev/null; then
        echo "✓ JSON 格式验证通过"
    else
        echo "✗ JSON 格式验证失败，可能存在格式错误"
    fi
else
    echo "提示: 未安装 jq，跳过 JSON 格式验证"
fi

echo "完成。用户信息已保存到: $(pwd)/$OUTPUT_FILE"
