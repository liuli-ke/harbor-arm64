# Harbor ARM64

## 从镜像里获取离线安装包

```bash
下载离线镜像包
docker pull liulik/harbor_images_aarch64:v2.11.2

创建一个新的容器实例
TEMP_CONTAINER_ID=$(docker create liulik/harbor_images_aarch64:v2.11.2 /bin/true)

从容器中拷贝文件
docker cp $TEMP_CONTAINER_ID:/harbor-offline-installer-aarch64-v2.11.2.tgz ./harbor-offline-installer-aarch64-v2.11.2.tgz

删除容器实例
docker rm $TEMP_CONTAINER_ID
```

## 从Release下载

```bash
wget https://github.com/liuli-ke/harbor-arm64/releases/download/v2.11.2/harbor-offline-installer-aarch64-v2.11.2.tgz
```

