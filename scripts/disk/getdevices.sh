#!/bin/bash

# 检查是否安装了 smartctl 工具
if ! command -v smartctl &> /dev/null
then
    echo "smartctl 未安装，正在安装..."
    sudo apt update
    sudo apt install -y smartmontools
fi

# 获取硬盘设备信息
devices=$(lsblk -dn -o NAME,TYPE,SIZE | grep disk | awk '{print $1}')

# 打印 Markdown 表格头，使用 printf 控制列宽度
printf "| %-16s | %-8s | %-8s | %-23s | %-16s | %-19s |\n" "硬盘设备" "类型" "容量" "使用时间" "逻辑卷" "挂载目录"
printf "|%-12s|%-8s|%-8s|%-20s|%-14s|%-14s|\n" "--------------" "--------" "--------" "---------------------" "----------------" "----------------"

# 遍历每个硬盘设备
for dev in $devices
do
    # 获取硬盘类型（固态还是机械）
    type=$(cat /sys/block/$dev/queue/rotational)
    if [ "$type" -eq "1" ]; then
        drive_type="机械"
    else
        drive_type="固态"
    fi

    # 获取硬盘容量
    size=$(lsblk -dn -o SIZE /dev/$dev)

    # 获取硬盘运行时间
    if [[ $dev == nvme* ]]; then
        # 处理 NVMe 硬盘的 Power On Hours
        power_on_hours=$(sudo smartctl -a /dev/$dev | grep "Power On Hours" | awk '{print $4}' | sed 's/,//g')
    else
        # 处理 SATA 硬盘的 Power On Hours
        power_on_hours=$(sudo smartctl -a /dev/$dev | grep "Power_On_Hours" | awk '{print $10}')
    fi

    # 计算运行年数
    if [ -z "$power_on_hours" ] || [ "$power_on_hours" == "-" ]; then
        power_on_hours="未知"
        years="未知"
    else
        years=$(echo "scale=2; $power_on_hours / 24 / 365" | bc)
    fi

    # 获取逻辑卷和挂载目录
    logical_volume=$(lsblk -r -o NAME,TYPE /dev/$dev | grep "lvm" | awk '{print $1}' | sed 's/[^a-zA-Z0-9_-]//g')
    if [ -z "$logical_volume" ]; then
        logical_volume="None"
    fi

    # 获取挂载目录
    mount_point=$(lsblk -no MOUNTPOINT /dev/$dev | grep -v "^$")
    if [ -z "$mount_point" ]; then
        # 检查是否有子设备挂载
        mount_point=$(lsblk -r -o MOUNTPOINT /dev/$dev | grep -v "^$")
        if [ -z "$mount_point" ]; then
            mount_point="None"
        fi
    fi

    # 使用 printf 控制列宽度输出
    printf "| %-12s | %-8s | %-6s | %-20s | %-14s | %-14s |\n" "/dev/$dev" "$drive_type" "$size" "$power_on_hours h ($years 年)" "$logical_volume" "$mount_point"
done
