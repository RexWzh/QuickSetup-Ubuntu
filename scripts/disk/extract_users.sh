#!/bin/bash

# 设置备份目录
BACKUP_DIR="/backup"

# 输出 JSON 文件
OUTPUT_FILE="user_info.json"

# 检查备份目录是否存在
if [ ! -d "$BACKUP_DIR" ]; then
    echo "错误: 备份目录 $BACKUP_DIR 不存在"
    exit 1
fi

# 检查关键文件是否存在
for file in "$BACKUP_DIR/etc/passwd" "$BACKUP_DIR/etc/group" "$BACKUP_DIR/etc/shadow"; do
    if [ ! -f "$file" ]; then
        echo "警告: 文件 $file 不存在"
    fi
done

# 开始 JSON 输出
echo "{" > "$OUTPUT_FILE"
echo "  \"users\": [" >> "$OUTPUT_FILE"

# 获取正常用户 (UID >= 1000 且有 home 目录的用户)
first_user=true
while IFS=: read -r username password uid gid gecos home shell; do
    # 只处理 UID >= 1000 的用户且 home 目录在 /home 下的用户
    if [ "$uid" -ge 1000 ] && [[ "$home" == /home/* ]]; then
        # 查找用户的密码哈希
        passwd_hash=$(grep "^$username:" "$BACKUP_DIR/etc/shadow" | cut -d: -f2)
        
        # 获取用户的组信息
        primary_group=$(grep "^[^:]*:x:$gid:" "$BACKUP_DIR/etc/group" | head -1 | cut -d: -f1)
        
        # 获取用户所属的附加组
        secondary_groups=()
        while IFS=: read -r group_name _ group_id members; do
            if [[ ",$members," == *",$username,"* ]] && [ "$group_id" != "$gid" ]; then
                secondary_groups+=("\"$group_name\"")
            fi
        done < "$BACKUP_DIR/etc/group"
        
        # 输出用户 JSON 条目
        if [ "$first_user" = true ]; then
            first_user=false
        else
            echo "    ," >> "$OUTPUT_FILE"
        fi
        
        echo "    {" >> "$OUTPUT_FILE"
        echo "      \"username\": \"$username\"," >> "$OUTPUT_FILE"
        echo "      \"uid\": $uid," >> "$OUTPUT_FILE"
        echo "      \"gid\": $gid," >> "$OUTPUT_FILE"
        echo "      \"home\": \"$home\"," >> "$OUTPUT_FILE"
        echo "      \"shell\": \"$shell\"," >> "$OUTPUT_FILE"
        echo "      \"password_hash\": \"$passwd_hash\"," >> "$OUTPUT_FILE"
        echo "      \"primary_group\": \"$primary_group\"," >> "$OUTPUT_FILE"
        
        # 确保二次组信息格式正确
        if [ ${#secondary_groups[@]} -eq 0 ]; then
            echo "      \"secondary_groups\": []" >> "$OUTPUT_FILE"
        else
            sec_groups=$(IFS=,; echo "${secondary_groups[*]}")
            echo "      \"secondary_groups\": [$sec_groups]" >> "$OUTPUT_FILE"
        fi
        
        echo "    }" >> "$OUTPUT_FILE"
    fi
done < "$BACKUP_DIR/etc/passwd"

echo "  ]," >> "$OUTPUT_FILE"
echo "  \"groups\": [" >> "$OUTPUT_FILE"

# 获取组信息 (GID >= 1000 的组)
first_group=true
while IFS=: read -r group_name _ group_id members; do
    if [ "$group_id" -ge 1000 ]; then
        if [ "$first_group" = true ]; then
            first_group=false
        else
            echo "    ," >> "$OUTPUT_FILE"
        fi
        
        # 拆分组成员为数组并处理为正确的 JSON
        member_json_arr=()
        IFS=',' read -ra member_array <<< "$members"
        
        for member in "${member_array[@]}"; do
            if [ -n "$member" ]; then
                member_json_arr+=("\"$member\"")
            fi
        done
        
        # 将数组转换为 JSON 格式的字符串
        if [ ${#member_json_arr[@]} -eq 0 ]; then
            member_json=""
        else
            member_json=$(IFS=,; echo "${member_json_arr[*]}")
        fi
        
        echo "    {" >> "$OUTPUT_FILE"
        echo "      \"name\": \"$group_name\"," >> "$OUTPUT_FILE"
        echo "      \"gid\": $group_id," >> "$OUTPUT_FILE"
        echo "      \"members\": [$member_json]" >> "$OUTPUT_FILE"
        echo "    }" >> "$OUTPUT_FILE"
    fi
done < "$BACKUP_DIR/etc/group"

echo "  ]" >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

# 验证 JSON 有效性（如果安装了 jq）
if command -v jq &> /dev/null; then
    if jq empty "$OUTPUT_FILE" 2>/dev/null; then
        echo "✓ JSON 格式验证通过"
    else
        echo "✗ JSON 格式验证失败，可能存在格式错误"
    fi
fi

echo "用户信息已导出到 $OUTPUT_FILE"
echo "共找到 $(grep -c "\"username\"" "$OUTPUT_FILE") 个用户账户"
echo "共找到 $(grep -c "\"name\":" "$OUTPUT_FILE") 个用户组"