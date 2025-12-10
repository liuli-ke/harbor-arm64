# Harbor ARM64

> 低版本没有计划构建

## 从镜像里获取离线安装包

```bash
version='v2.14.0'

# 下载离线镜像包
docker pull liulik/harbor_images_aarch64:${version}

# 创建一个新的容器实例
## v2.11.2 v2.12.0 v2.12.1 v2.12.2 v2.12.3 v2.12.4 v2.13.0 v2.13.1 v2.13.2 v2.14.0 可用
TEMP_CONTAINER_ID=$(docker create liulik/harbor_images_aarch64:${version} /bin/true)
## v2.13.0+ 可用
TEMP_CONTAINER_ID=$(docker create liulik/harbor_aarch64_images:${version} /bin/true)

# 从容器中拷贝文件
docker cp $TEMP_CONTAINER_ID:/harbor-offline-installer-aarch64-${version}.tgz ./harbor-offline-installer-aarch64-${version}.tgz

# 删除容器实例
docker rm $TEMP_CONTAINER_ID
```

## 从Release下载

```bash
wget https://github.com/liuli-ke/harbor-arm64/releases/download/${version}/harbor-offline-installer-aarch64-${version}.tgz
```

