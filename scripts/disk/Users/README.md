# 用户与组管理脚本 (User & Group Management Scripts)

本目录包含用于备份和智能还原 Linux 用户及组配置的脚本工具。数据采用 **JSONL (JSON Lines)** 格式存储，方便流式处理和人工筛选。

主要场景：**多服务器环境一致性同步**（例如 NFS 共享需要各节点 UID/GID 一致）、系统迁移。

## 依赖项 (Prerequisites)

脚本依赖 `jq` 工具来解析 JSON 数据。
```bash
sudo apt install jq -y
```

## 脚本详解 (Scripts Detail)

### 1. 导出脚本: `export_users_json.sh`

*   **功能**: 导出当前系统中所有普通用户（UID >= 1000）及其组信息。
*   **输出**: `users_info.jsonl` (每一行是一个独立的 JSON 对象)
*   **操作逻辑**:
    1.  读取 `/etc/group`，筛选 GID >= 1000 的组，导出为 `type: "group"` 记录。
    2.  读取 `/etc/passwd`，筛选 UID >= 1000 的用户（排除 nobody），导出为 `type: "user"` 记录。
    3.  尝试读取 `/etc/shadow` 获取密码哈希（需要 root 权限），以便还原时保留密码。
*   **用法**:
    ```bash
    sudo ./export_users_json.sh
    ```

### 2. 智能还原脚本: `restore_users_smart.sh`

*   **功能**: 读取 JSONL 备份文件，将当前系统的用户状态**同步**到备份状态。
*   **核心理念**: **"Check & Update" (检查并更新)**。优先修改现有用户，而非删除重建。
*   **用法**:
    ```bash
    sudo ./restore_users_smart.sh [-f] [-p] [-c] users_info.jsonl
    ```
    *   `-f`: **强制模式 (Force)**。遇到 UID/GID 冲突时，自动将占用者移动到新的空闲 ID，从而释放目标 ID。
    *   `-p`: **更新密码 (Password)**。默认不还原密码（保留现有密码）。加上此选项强制同步备份中的密码。
    *   `-c`: **创建用户 (Create)**。默认仅更新现有用户，跳过不存在的用户。加上此选项才会创建新用户。

#### 详细处理逻辑 (Processing Logic)

脚本按顺序逐行读取 JSONL 文件，先处理组，再处理用户。

1.  **组处理 (Group Processing)**:
    *   **检查**: 组名是否存在？
    *   **存在**: 检查 GID 是否匹配。如果不匹配，尝试修改 (`groupmod -g`)。
    *   **不存在**: 创建新组 (`groupadd -g`)。

2.  **用户处理 (User Processing)**:
    *   **步骤 B: 检查用户状态**:
        *   **如果用户已存在**:
            *   **确保主组就绪**: 确保 Primary Group 存在且 GID 正确。
            *   对比 UID：如果不同，尝试修改 UID (`usermod -u`)。
            *   对比主组 GID：如果不同，修改主组 (`usermod -g`)。
            *   更新 Shell 和 Home 目录路径。
            *   **文件权限修复**: 递归修改 Home 目录下所有文件的所有者为新的 UID:GID (确保文件归属正确)。
        *   **如果用户不存在**:
            *   **默认**: 跳过 (Skip)。避免污染系统。
            *   **使用 -c**: 
                *   确保主组就绪。
                *   直接创建新用户 (`useradd`)，指定 UID、GID、Home、Shell。
                *   如果 Home 目录不存在，则创建并设置权限 (`cp -r /etc/skel` 逻辑由 mkdir 替代，仅创建空目录并 chown)。
    *   **步骤 C: 还原密码**:
        *   **默认**: 跳过密码更新（保留系统当前密码）。
        *   **使用 -p**: 如果备份中有密码且与当前不一致，则强制覆盖 (`chpasswd -e`)。
    *   **步骤 D: 附加组**:
        *   将用户加入到备份中记录的所有附加组 (`usermod -G`)。

#### 冲突处理机制 (Conflict Handling)

这是最关键的部分。当脚本试图修改 UID/GID 或创建用户时，可能会遇到 ID 被占用的情况。

**场景 1: 用户名存在，但需要修改 UID**
*   **情况**: 备份中 UserA 的 UID 是 1001。当前系统中 UserA 的 UID 是 1002。脚本试图将 UserA 改为 1001。
*   **冲突检测**: 脚本会检查 **目标 UID 1001** 当前是否被其他用户（例如 UserB）占用。
*   **处理**:
    *   **如果 1001 空闲**: 执行 `usermod -u 1001 UserA`。系统会自动修改 UserA 主目录下所有文件的归属权。
    *   **如果 1001 被 UserB 占用**:
        *   **动作**: **默认跳过 (SKIP)** 并报错。
        *   **原因**: 防止意外破坏 UserB 的环境。
        *   **解决**: 
            *   **默认**: 需要人工介入。
            *   **使用 -f**: 脚本会自动找到一个空闲 UID (例如 MaxUID + 1)，将 UserB 移动过去，然后将 UserA 修改为目标 UID 1001。

**场景 2: 用户不存在，需要创建新用户**
*   **情况**: 备份中有 UserA (UID 1001)。当前系统没有 UserA。
*   **冲突检测**: 检查 UID 1001 是否被占用。
*   **处理**:
    *   **如果 1001 被 UserB 占用**: 
        *   **默认**: 跳过创建并报错。
        *   **使用 -f**: 移动 UserB 到空闲 UID，然后创建 UserA。

**场景 3: 组 GID 冲突**
*   **情况**: 组 GroupA 需要 GID 2000，但 GID 2000 被 GroupB 占用。
*   **处理**: 
    *   **默认**: 跳过修改并报错。
    *   **使用 -f**: 移动 GroupB 到空闲 GID，然后修改 GroupA。

### 总结

*   脚本**永远不会删除**现有的用户或数据。
*   脚本**不会强制覆盖**已占用的 ID。
*   遇到 ID 冲突时，脚本选择**安全失败 (Fail Safe)**，即报错并跳过该条目，保留现状，等待人工决策。
