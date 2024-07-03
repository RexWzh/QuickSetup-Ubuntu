# QuickSetup-Ubuntu

## 简介

QuickSetup-Ubuntu 提供一个脚本，能快速为 Ubuntu 系统安装所有必要的软件包和以来。

当前脚本涉及的命令及含义，均可以在这里：[Ubuntu 教程(一) | 必备软件的安装和配置](https://www.wzhecnu.cn/2021/08/20/server/02-ubuntu-basicapp/) 找到。

对于新装的系统，写一个脚本很方便，但为了兼容各种复杂的情况，特别是系统安装并修改过了很多内容，要再根据各类边界条件完善脚本。

## 使用说明

一行命令安装：

```bash
curl -sL https://raw.githubusercontent.com/RexWzh/QuickSetup-Ubuntu/main/scripts/quick-setup.sh | bash
```

定制化安装：克隆仓库或从模板创建仓库，按个人使用习惯，修改配置文件

```bash
git clone https://github.com/RexWzh/QuickSetup-Ubuntu.git
cd QuickSetup-Ubuntu
# edit config.toml/pkg_source
bash scripts/quick-setup-local.sh
```

## 配置

脚本的配置通过 `config/config.yaml` 文件进行管理。你可以在此文件中指定安装所需的各类选项和设置。

## 贡献

请阅读 `CONTRIBUTING.md` 了解详细的行为准则及提交拉取请求的流程。

## 许可证

此项目基于 MIT 许可证，详情请参阅 `LICENSE` 文件。