#!/usr/bin/env bash
set -e

echo "🔍 Checking Docker environment..."

# 检查 Docker 是否存在
check_docker() {
    if command -v docker &> /dev/null; then
        echo "✅ Docker is installed"
        docker --version
    else
        echo "❌ Docker is not installed"
        exit 1
    fi
}

# 检查 Docker Compose 是否存在
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        echo "✅ Docker Compose is installed"
        docker-compose --version
    else
        echo "⚠️ Docker Compose is not installed, checking Docker Compose Plugin..."
        if docker compose version &> /dev/null; then
            echo "✅ Docker Compose Plugin is available"
        else
            echo "❌ Neither Docker Compose nor Docker Compose Plugin is available"
            exit 1
        fi
    fi
}

# 检查 Docker Buildx 是否存在
check_docker_buildx() {
    if docker buildx version &> /dev/null; then
        echo "✅ Docker Buildx is installed"
        docker buildx version
    else
        echo "❌ Docker Buildx is not installed"
        exit 1
    fi
}

# 检查是否支持运行 ARM 镜像
check_arm_support() {
    echo "🔍 Checking ARM architecture support..."
    if docker run --rm --platform linux/arm64 arm64v8/alpine:latest uname -m &> /dev/null; then
        echo "✅ ARM64 image execution is supported"
        return 0
    else
        echo "❌ ARM64 image execution is not supported"
        return 1
    fi
}

# 安装 QEMU 静态二进制文件支持
install_arm_support() {
    echo "🚀 Installing ARM architecture support..."

    echo "Installing binfmt support..."
    if ! docker run --rm --privileged tonistiigi/binfmt:latest --install all; then
        echo "❌ Failed to install binfmt support"
        return 1
    fi

    echo "Installing QEMU static binaries..."
    if ! docker run --rm --privileged multiarch/qemu-user-static:latest --reset -p yes; then
        echo "❌ Failed to install QEMU static binaries"
        return 1
    fi

    # 等待一段时间让系统注册新的二进制格式
    sleep 5

    echo "✅ ARM architecture support installation completed"
}

# 主函数
main() {
    echo "=== Docker Environment Check ==="

    # 检查基础组件
    check_docker
    check_docker_compose
    check_docker_buildx

    # 检查 ARM 支持
    if check_arm_support; then
        echo "🎉 Environment is ready for ARM64 image building"
        return 0
    else
        echo "🛠️ ARM support not detected, attempting to install..."
        if install_arm_support; then
            echo "🔍 Verifying ARM support after installation..."
            if check_arm_support; then
                echo "🎉 ARM support successfully installed and verified"
                return 0
            else
                echo "❌ ARM support installation failed verification"
                return 1
            fi
        else
            echo "❌ Failed to install ARM support"
            return 1
        fi
    fi
}

# 运行主函数
main