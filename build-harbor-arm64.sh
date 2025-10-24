#!/bin/bash

# 配置参数
# 分支名
BRANCH="v2.12.1"
REPO_URL="https://gitee.com/liuli-ke/harbor-aarch64.git"
REPO_DIR="harbor-aarch64"

# 检查是否安装了git
if ! command -v git &> /dev/null; then
    echo "错误: 未找到git，请先安装git"
    exit 1
fi

# 检查是否安装了wget
if ! command -v wget &> /dev/null; then
    echo "错误: 未找到wget，请先安装wget"
    exit 1
fi

echo "检查通过: git和wget已安装"

# 克隆仓库
echo "正在克隆仓库..."
if git clone "$REPO_URL"; then
    echo "仓库克隆成功"
else
    echo "错误: 仓库克隆失败"
    exit 1
fi

# 进入仓库目录
cd "$REPO_DIR" || {
    echo "错误: 无法进入目录 $REPO_DIR"
    exit 1
}

# 切换到指定分支
echo "正在切换到分支: $BRANCH"
if git checkout "$BRANCH"; then
    echo "成功切换到分支: $BRANCH"
else
    echo "错误: 无法切换到分支 $BRANCH"
    echo "可用的分支有:"
    git branch -a
    exit 1
fi

# 检查build-harbor.sh脚本是否存在
if [ ! -f "build-harbor.sh" ]; then
    echo "错误: 未找到 build-harbor.sh 脚本"
    echo "当前目录中的文件:"
    ls -la
    exit 1
fi

# 给脚本添加执行权限
chmod +x build-harbor.sh

# 执行构建脚本
echo "正在执行 build-harbor.sh 脚本..."
./build-harbor.sh
