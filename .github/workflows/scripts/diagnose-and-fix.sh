#!/bin/bash
set -e

echo "🔍 Harbor 构建失败诊断与修复脚本启动..."
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}ℹ️ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 1. 检查系统资源
check_system_resources() {
    log_info "1. 检查系统资源..."

    echo "--- 磁盘使用情况 ---"
    df -h

    echo "--- 内存使用情况 ---"
    free -h

    echo "--- 内存详细信息 ---"
    cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree)"

    echo "--- 当前进程内存使用 ---"
    ps aux --sort=-%mem | head -10
}

# 2. 检查 Docker 资源
check_docker_resources() {
    log_info "2. 检查 Docker 资源..."

    echo "--- Docker 系统信息 ---"
    docker system df

    echo "--- Docker 镜像列表 ---"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | head -20

    echo "--- Docker 容器状态 ---"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}" | head -10

    echo "--- Docker 存储驱动信息 ---"
    docker info 2>/dev/null | grep -A 10 "Storage" || echo "无法获取 Docker 存储信息"
}

# 3. 检查 Harbor 相关镜像状态
check_harbor_images() {
    log_info "3. 检查 Harbor 相关镜像状态..."

    echo "--- Harbor 相关镜像 ---"
    docker images | grep -E "(harbor|goharbor)" | sort || echo "未找到 Harbor 相关镜像"

    # 特别检查 exporter 相关镜像
    echo "--- Exporter 相关镜像详细检查 ---"
    docker images | grep -E "(exporter|exporter-base)" | sort || echo "未找到 exporter 相关镜像"

    # 验证基础镜像完整性
    log_info "验证基础镜像完整性..."
    if docker images | grep -q "harbor-exporter-base"; then
        log_info "发现 harbor-exporter-base 镜像，验证其可用性..."
        if ! docker run --rm harbor-exporter-base:${HARBOR_IMAGE_TAG:-dev} echo "基础镜像测试" 2>/dev/null; then
            log_warn "harbor-exporter-base 镜像可能损坏"
        else
            log_info "harbor-exporter-base 镜像可用性验证通过"
        fi
    fi
}

# 4. 清理和修复操作
cleanup_and_fix() {
    log_info "4. 执行清理和修复操作..."

    # 停止所有运行中的容器（除了必要的）
    log_info "停止非必要容器..."
    docker ps -q | xargs -r docker stop 2>/dev/null || true

    # 清理 Docker 资源
    log_info "清理 Docker 构建缓存..."
    docker builder prune -a -f

    log_info "清理未使用的容器..."
    docker container prune -f

    log_info "清理未使用的镜像..."
    docker image prune -a -f

    log_info "清理未使用的卷..."
    docker volume prune -f

    log_info "清理未使用的网络..."
    docker network prune -f

    # 特别清理可能损坏的 Harbor 镜像
    log_info "清理可能损坏的 Harbor 镜像..."
    docker images --filter "reference=*exporter*" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true
    docker images --filter "reference=*exporter-base*" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true

    # 清理 Go 编译缓存
    log_info "清理 Go 编译缓存..."
    if [ -d "/tmp/go-build" ]; then
        rm -rf /tmp/go-build* 2>/dev/null || true
    fi
    if [ -d "/root/.cache/go-build" ]; then
        rm -rf /root/.cache/go-build 2>/dev/null || true
    fi

    # 检查并尝试修复磁盘空间
    log_info "检查大文件..."
    find /tmp /var/tmp -type f -size +100M 2>/dev/null | head -5 || true
}

# 5. 优化系统设置
optimize_system() {
    log_info "5. 优化系统设置..."

    # 增加交换空间（如果内存不足）
    if [ "$(free -h | grep Swap | awk '{print $2}')" = "0B" ]; then
        log_warn "未检测到交换空间，尝试创建..."
        sudo fallocate -l 2G /swapfile 2>/dev/null || true
        sudo chmod 600 /swapfile 2>/dev/null || true
        sudo mkswap /swapfile 2>/dev/null || true
        sudo swapon /swapfile 2>/dev/null || true
    fi

    # 调整 Docker 守护进程设置（如果可能）
    if [ -w "/etc/docker/daemon.json" ]; then
        log_info "优化 Docker 守护进程配置..."
        cat << EOF | sudo tee /etc/docker/daemon.json >/dev/null 2>&1 || true
{
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF
        sudo systemctl restart docker 2>/dev/null || true
    fi
}

# 6. 生成诊断报告
generate_report() {
    log_info "6. 生成诊断报告..."

    echo "=========================================="
    echo "📊 诊断报告摘要"
    echo "=========================================="

    # 磁盘使用
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    echo "📦 根分区使用率: ${DISK_USAGE}%"

    # 内存使用
    MEM_USAGE=$(free | awk 'NR==2{printf "%.2f%%", $3*100/$2}')
    echo "💾 内存使用率: ${MEM_USAGE}"

    # Docker 磁盘使用
    # 尝试多种方法获取磁盘使用情况
    local usage=""
    # 方法1：使用标准输出解析
    usage=$(docker system df 2>/dev/null | awk 'NR==2{print $3}')
    if [ -z "$usage" ] || [ "$usage" = "SIZE" ]; then
        # 方法2：使用格式化输出
        usage=$(docker system df --format "table {{.Size}}" 2>/dev/null | tail -n +2 | head -1)
    fi
    echo "🐳 Docker 占用空间: ${usage:-未知}"

    # Harbor 镜像状态
    HARBOR_IMAGES=$(docker images | grep -c "harbor\|goharbor" || true)
    echo "🏗️ Harbor 相关镜像数量: ${HARBOR_IMAGES}"

    # 建议
    echo ""
    echo "💡 建议操作:"
    if [ "${DISK_USAGE}" -gt 85 ]; then
        echo "  - 磁盘空间严重不足，建议清理更多空间"
    fi

    if docker images | grep -q "exporter-base" && ! docker run --rm harbor-exporter-base:${HARBOR_IMAGE_TAG:-dev} echo "test" >/dev/null 2>&1; then
        echo "  - 检测到损坏的基础镜像，建议重新构建"
    fi
}

# 主执行函数
main() {
    log_info "开始 Harbor 构建失败诊断..."

    check_system_resources
    check_docker_resources
    check_harbor_images
    cleanup_and_fix
    optimize_system
    generate_report

    log_info "诊断完成！建议："
    log_info "1. 检查上述报告中的资源使用情况"
    log_info "2. 如果磁盘/内存不足，考虑升级 GitHub Actions 运行器"
    log_info "3. 重新运行构建工作流"
    log_info "4. 如果问题持续，检查构建脚本中的参数传递"
}

# 执行主函数
main "$@"