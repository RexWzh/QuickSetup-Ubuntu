#!/bin/bash

# Nvidia CUDA 安装脚本
# cuda 版本选择: https://developer.nvidia.com/cuda-toolkit-archive

set -e  # 遇到错误时退出

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 定义输出函数
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

print_header "CUDA 安装脚本启动"

# CUDA 版本设置 (可根据需要修改)
cuda_version="12-8"  # 默认使用 CUDA 12.8

# 1. 自动检测系统版本和架构
print_step "检测系统信息..."

# 获取 Ubuntu 版本
ubuntu_version=$(lsb_release -rs | tr -d '.')
case $ubuntu_version in
    "2004")
        version="ubuntu2004"
        ;;
    "2204")
        version="ubuntu2204"
        ;;
    "2404")
        version="ubuntu2404"
        ;;
    *)
        print_warning "未识别的 Ubuntu 版本 $(lsb_release -rs)，使用默认版本 ubuntu2204"
        version="ubuntu2204"
        ;;
esac

# 获取系统架构
arch=$(uname -m)
case $arch in
    "x86_64")
        arch="x86_64"
        ;;
    "aarch64")
        arch="sbsa"
        ;;
    *)
        print_warning "未识别的架构 $arch，使用默认架构 x86_64"
        arch="x86_64"
        ;;
esac

echo -e "${WHITE}检测到的系统信息:${NC}"
echo -e "  ${GREEN}Ubuntu 版本:${NC} $version"
echo -e "  ${GREEN}系统架构:${NC} $arch"
echo -e "  ${GREEN}CUDA 版本:${NC} $cuda_version"

# 2. 检查现有安装情况
print_header "检查现有安装情况"

# 更新 PCI 设备数据库
print_info "更新 PCI 设备数据库..."
sudo update-pciids

# 显示显卡信息
print_step "检查显卡信息..."
echo -e "${YELLOW}VGA 设备:${NC}"
lspci | grep -i vga || echo -e "${RED}未检测到 VGA 设备${NC}"

echo -e "${YELLOW}NVIDIA 设备:${NC}"
if lspci | grep -i nvidia; then
    print_success "检测到 NVIDIA 设备"
else
    print_error "未检测到 NVIDIA 设备"
fi

# 检查已安装的 NVIDIA 相关包
print_step "检查已安装的软件包..."

echo -e "${YELLOW}NVIDIA 驱动信息:${NC}"
if dpkg -l | grep nvidia; then
    print_success "已安装 NVIDIA 相关包"
else
    print_info "未安装 NVIDIA 驱动"
fi

echo -e "${YELLOW}CUDA 相关包信息:${NC}"
if dpkg -l | grep cuda; then
    print_success "已安装 CUDA 相关包"
else
    print_info "未安装 CUDA"
fi

echo -e "${YELLOW}cuDNN 相关包信息:${NC}"
if dpkg -l | grep cudnn; then
    print_success "已安装 cuDNN 相关包"
else
    print_info "未安装 cuDNN"
fi

# 3. 安装 NVIDIA 驱动
print_header "安装 NVIDIA 驱动"

# 检查是否已有合适的驱动
if nvidia-smi &>/dev/null; then
    print_success "检测到已安装的 NVIDIA 驱动:"
    echo -e "${GREEN}驱动版本:${NC} $(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits)"
else
    print_info "未检测到 NVIDIA 驱动，开始自动安装..."
    sudo ubuntu-drivers autoinstall
    print_success "驱动安装完成"
fi

# 4. 安装 CUDA
print_header "安装 CUDA"

# 下载并安装 CUDA keyring
print_step "下载 CUDA keyring..."
cuda_keyring_url="https://developer.download.nvidia.com/compute/cuda/repos/$version/$arch/cuda-keyring_1.1-1_all.deb"
echo -e "${CYAN}下载地址:${NC} $cuda_keyring_url"

print_info "正在下载..."
wget -O /tmp/cuda-keyring.deb "$cuda_keyring_url"
print_success "下载完成"

print_info "安装 keyring..."
sudo dpkg -i /tmp/cuda-keyring.deb
print_success "Keyring 安装完成"

# 更新包列表
print_info "更新软件包列表..."
sudo apt-get update

# 安装 CUDA toolkit
print_step "安装 CUDA toolkit $cuda_version..."

# 判断 CUDA 版本，决定安装命令
cuda_major=$(echo $cuda_version | cut -d'-' -f1)
cuda_minor=$(echo $cuda_version | cut -d'-' -f2)

# 将版本转换为数字进行比较 (例如: 12.3 -> 1203)
cuda_version_num=$((cuda_major * 100 + cuda_minor))

if [ $cuda_version_num -lt 1203 ]; then
    # CUDA 版本 < 12.3，不需要指定版本
    print_info "CUDA 版本 < 12.3，使用通用安装命令"
    sudo apt-get install -y cuda
else
    # CUDA 版本 >= 12.3，需要指定版本
    print_info "CUDA 版本 >= 12.3，使用版本特定安装命令"
    sudo apt-get install -y cuda-toolkit-$cuda_version
fi

print_success "CUDA toolkit 安装完成"

# 5. 设置环境变量
print_header "设置环境变量"

# 检查 CUDA 安装路径
cuda_path="/usr/local/cuda"
if [ -d "$cuda_path" ]; then
    print_success "找到 CUDA 安装路径: $cuda_path"
    
    # 添加到 ~/.bashrc
    if ! grep -q "CUDA_HOME" ~/.bashrc; then
        echo "" >> ~/.bashrc
        echo "# CUDA 环境变量" >> ~/.bashrc
        echo "export CUDA_HOME=$cuda_path" >> ~/.bashrc
        echo "export PATH=\$CUDA_HOME/bin:\$PATH" >> ~/.bashrc
        echo "export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH" >> ~/.bashrc
        print_success "CUDA 环境变量已添加到 ~/.bashrc"
    else
        print_info "CUDA 环境变量已存在于 ~/.bashrc"
    fi
    
    # 添加到 ~/.zshrc (如果存在)
    if [ -f ~/.zshrc ] && ! grep -q "CUDA_HOME" ~/.zshrc; then
        echo "" >> ~/.zshrc
        echo "# CUDA 环境变量" >> ~/.zshrc
        echo "export CUDA_HOME=$cuda_path" >> ~/.zshrc
        echo "export PATH=\$CUDA_HOME/bin:\$PATH" >> ~/.zshrc
        echo "export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH" >> ~/.zshrc
        print_success "CUDA 环境变量已添加到 ~/.zshrc"
    fi
else
    print_error "未找到 CUDA 安装路径 $cuda_path"
fi

# 6. 验证安装
print_header "验证安装"

# 临时设置环境变量用于验证
export CUDA_HOME=$cuda_path
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# 检查 CUDA 版本
print_step "检查 CUDA 编译器..."
if command -v nvcc &> /dev/null; then
    print_success "CUDA 编译器可用"
    echo -e "${YELLOW}CUDA 编译器版本:${NC}"
    nvcc --version
else
    print_error "nvcc 命令未找到，请检查安装和环境变量设置"
fi

# 检查 NVIDIA 驱动和 CUDA 兼容性
print_step "检查 NVIDIA 驱动状态..."
if command -v nvidia-smi &> /dev/null; then
    print_success "NVIDIA 驱动可用"
    echo -e "${YELLOW}NVIDIA 驱动信息:${NC}"
    nvidia-smi
else
    print_error "nvidia-smi 命令未找到，请检查驱动安装"
fi

# 清理临时文件
print_info "清理临时文件..."
rm -f /tmp/cuda-keyring.deb
print_success "清理完成"

print_header "安装完成"
print_success "CUDA 安装成功完成!"
echo -e "${CYAN}请重新加载环境变量或重启终端:${NC}"
echo -e "  ${GREEN}source ~/.bashrc${NC}"
echo -e "${CYAN}或者${NC}"
echo -e "  ${GREEN}source ~/.zshrc${NC}"
