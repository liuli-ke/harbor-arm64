#!/bin/bash
# 显示所有Docker镜像的详细信息

echo "镜像名称:Tag                                          架构      大小       创建时间"
echo "================================================================================"

docker images --format "{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}" | while IFS=$'\t' read image id size created; do
    if [ -n "$image" ] && [ "$image" != "<none>:<none>" ]; then
        architecture=$(docker inspect --format "{{.Architecture}}" "$id" 2>/dev/null || echo "未知")
        # 提取日期部分，去掉时间
        create_date=$(echo "$created" | cut -d' ' -f1)
        printf "%-50s %-10s %-10s %s\n" "$image" "$architecture" "$size" "$create_date"
    fi
done
