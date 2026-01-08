# 用户与组管理脚本 (User & Group Management Scripts)

本目录包含用于备份、提取和还原 Linux 用户及组配置的脚本工具。主要用于系统迁移、备份恢复或多服务器间的用户环境同步（如 NFS 环境下的 UID/GID 统一）。

## 依赖项 (Prerequisites)

所有脚本均依赖 `jq` 工具来处理 JSON 数据。

```bash
sudo apt install jq -y
```

## 脚本列表与用法 (Scripts Overview)

### 1. 导出/备份 (Export & Backup)

#### `export_users_json.sh`
*   **功能**: 从**当前系统**导出所有普通用户（UID >= 1000）及其组信息、密码哈希。
*   **输出**: `users_info.json`
*   **用法**:
    ```bash
    sudo ./export_users_json.sh
    ```
*   **注意**: 需要 root 权限以读取 `/etc/shadow` 中的密码哈希。

---

### 2. 还原/同步 (Restore & Sync)

#### `restore_users_smart.sh` (推荐 / Recommended)
*   **功能**: **智能还原/同步**。不仅能创建新用户，还能**修改现有用户**的 UID/GID 以匹配备份文件。
*   **特点**:
    *   **非破坏性**: 不会删除用户，而是使用 `usermod`/`groupmod` 原地修改。
    *   **自动修复权限**: 修改 UID 时会自动修复用户主目录下文件的归属权。
    *   **幂等性**: 可重复运行，已匹配的用户会自动跳过。
*   **场景**: 多服务器用户 ID 统一、系统迁移恢复。
*   **用法**:
    ```bash
    sudo ./restore_users_smart.sh users_info.json
    ```

## 典型工作流 (Workflow Example)

### 场景：将服务器 A 的用户同步到服务器 B (UID/GID 统一)

1.  **在服务器 A (源) 上导出**:
    ```bash
    sudo ./export_users_json.sh
    # 生成 users_info.json
    ```

2.  **传输文件**: 将 `users_info.json` 复制到服务器 B。

3.  **在服务器 B (目标) 上同步**:
    ```bash
    # 安装依赖
    sudo apt install jq
    
    # 运行智能还原
    sudo chmod +x restore_users_smart.sh
    sudo ./restore_users_smart.sh users_info.json
    ```
    *此时，服务器 B 上存在的用户 UID/GID 将被修正为与 A 一致（文件权限也会自动修正），不存在的用户将被创建。*

## 注意事项 (Precautions)

1.  **Root 权限**: 所有操作均涉及系统核心配置文件 (`/etc/passwd`, `/etc/shadow`)，必须使用 `sudo` 或 root 身份运行。
2.  **数据安全**: 
    *   `restore_users_smart.sh` 修改 UID 时会自动执行 `chown` 修复主目录权限，但在极其特殊的文件系统或挂载点上可能需要人工检查。
    *   **不要**在正在运行关键业务（如数据库服务用户）的系统上随意修改 UID，除非你确信该用户不影响服务运行。
3.  **冲突处理**: 如果目标 UID 已被其他**不相关**的系统用户占用（例如系统服务账户），智能脚本会为了安全而跳过修改并报错，此时需要人工介入解决冲突。
