# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY ujust /ujust

# Base Image
FROM ghcr.io/ublue-os/base-main:latest

RUN rm /opt && mkdir /opt

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
