# Kernel packages come from the matching ublue akmods image.
# Floating akmods tag: it tracks the latest kernel for this Fedora release, so
# there is no exact version to go stale when ublue rebuilds.
ARG FEDORA_VERSION="${FEDORA_VERSION:-45}"
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-ogc}"

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY ujust /ujust

# Cached kernel RPMs (/kernel-rpms), mounted into the build stage below
FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION} AS akmods

# Base Image
FROM ghcr.io/ublue-os/base-main:${FEDORA_VERSION}

RUN rm /opt && mkdir /opt

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=akmods,src=/kernel-rpms,dst=/tmp/kernel-rpms \
    --mount=type=bind,from=akmods,src=/rpms,dst=/tmp/akmods-rpms \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
