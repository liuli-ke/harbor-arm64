FROM scratch
ARG version=v2.12.2
COPY harbor/harbor-offline-installer-aarch64-${version}.tgz /
