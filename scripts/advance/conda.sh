#!/bin/bash

# 创建下载目录
DOWNLOAD_DIR=~/downloads
mkdir -p $DOWNLOAD_DIR

# 下载 Miniconda 安装脚本的 URL 和文件名
CONDA_SCRIPT="Miniconda3-latest-Linux-x86_64.sh"
CONDA_URL="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/$CONDA_SCRIPT"

# 检查 conda 是否已经安装
if command -v conda &> /dev/null; then
    echo "Conda 已经安装，跳过安装步骤"
else
    # 下载 Miniconda 安装脚本
    wget -c $CONDA_URL -O "$DOWNLOAD_DIR/$CONDA_SCRIPT"

    # 使用批处理模式安装 Miniconda 到 ~/miniconda3
    bash "$DOWNLOAD_DIR/$CONDA_SCRIPT" -b -p ~/miniconda3
    
    # 检查是否成功安装
    if [[ $? -ne 0 ]]; then
        echo "Miniconda 安装失败，请检查安装脚本和网络连接。"
        exit 1
    fi

    # 安装成功，添加 Conda 到当前 shell 的路径
    if [[ "$SHELL" == *"zsh" ]]; then
        RC_FILE=~/.zshrc
    elif [[ "$SHELL" == *"bash" ]]; then
        RC_FILE=~/.bashrc
    else
        echo "Unsupported shell: $SHELL"
        exit 1
    fi

    # 在配置文件中添加 Conda 初始化操作
    CONDA_INIT='export PATH="$HOME/miniconda3/bin:$PATH"'
    if ! grep -Fxq "$CONDA_INIT" $RC_FILE; then
        echo "$CONDA_INIT" >> $RC_FILE
        echo "Conda initialization added to $RC_FILE"
    else
        echo "Conda initialization already exists in $RC_FILE"
    fi

    # 提示用户重新加载配置文件
    echo "Please run 'source $RC_FILE' to apply the changes."

    # 初始化 conda (可选)
    echo "Initializing Conda..."
    source "$HOME/miniconda3/bin/conda" init
    if [[ $? -ne 0 ]]; then
        echo "Conda initialization failed. Please check the installation."
        exit 1
    fi
    # 配置 bash 和 zsh
    if [[ -f ~/.bashrc ]]; then
        echo "Configuring bash..."
        source "$HOME/miniconda3/bin/conda" init bash
    fi
    if [[ -f ~/.zshrc ]]; then
        echo "Configuring zsh..."
        source "$HOME/miniconda3/bin/conda" init zsh
    fi

    echo "Miniconda installation script completed. Please restart your shell or run 'source $RC_FILE' to start using Conda."
fi