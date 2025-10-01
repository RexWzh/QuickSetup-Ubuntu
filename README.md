# QuickSetup-Ubuntu

🚀 一键搞定 Ubuntu 系统配置，告别重复安装的烦恼！

## 这是什么？

新装了 Ubuntu 系统，又要重新安装一堆软件？这个脚本帮你一次性搞定：
- 常用软件包安装
- 开发环境配置  
- 系统优化设置
- 个性化配置

详细的命令说明可以看这里：[Ubuntu 教程 | 必备软件安装配置](https://www.wzhecnu.cn/2021/08/20/server/02-ubuntu-basicapp/)

## 快速开始

### 🎯 一键安装

```bash
curl -sL https://raw.githubusercontent.com/RexWzh/QuickSetup-Ubuntu/main/scripts/quick-setup.sh | bash
```

### 🛠️ 自定义安装

点击仓库的 "Use this template" 选项，根据自己需求进行个性化的配置调整：

```bash
git clone https://github.com/RexWzh/QuickSetup-Ubuntu.git
cd QuickSetup-Ubuntu
# 根据需要编辑 config.toml 和 pkg_source 目录
bash scripts/quick-setup-local.sh
```

## 许可证

此项目基于 MIT 许可证，详情请参阅 `LICENSE` 文件。

## 📁 项目结构

```
scripts/
├── advance/        # 高级工具 (Docker, Conda, Node.js 等)
├── apts/          # APT 软件包安装
├── config/        # 配置文件
├── debs/          # DEB 包安装
├── disk/          # 磁盘和用户管理
├── others/        # 其他工具
└── secure/        # 安全配置
```

## ⚙️ 配置说明

配置文件在 `config/config.toml`，可以根据需要开启或关闭特定功能。

## 🤝 参与贡献

发现 bug 或有好的想法？欢迎提 Issue 或 PR！

## 📄 开源协议

MIT License - 随便用，记得点个 ⭐