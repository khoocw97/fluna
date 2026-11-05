#!/usr/bin/env bash
#
# Kernel.
#
# The kernel RPMs come from the akmods image mounted at /tmp/kernel-rpms, which
# is also where any future out-of-tree module would come from.
#
set -xeuo pipefail

echo "::group::Install kernel and akmods"
trap 'echo "::endgroup::"' EXIT

# -- Bypass kernel-install triggers while swapping kernels --
pushd /usr/lib/kernel/install.d
cp -f 05-rpmostree.install 05-rpmostree.install.bak
cp -f 50-dracut.install 50-dracut.install.bak
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install
chmod +x 05-rpmostree.install 50-dracut.install
popd

# -- Remove the Fedora kernel from the base image --
mapfile -t OLD_KERNELS < <(rpm -qa | grep -E '^kernel(-core|-modules|-modules-core|-modules-extra|-devel|-devel-matched|-tools|-tools-libs)?-[0-9]' || true)
if [[ "${#OLD_KERNELS[@]}" -gt 0 ]]; then
    rpm --erase --allmatches --nodeps "${OLD_KERNELS[@]}"
fi
rm -rf /usr/lib/modules

# -- Install the OGC kernel --
dnf5 -y install \
    /tmp/kernel-rpms/kernel-[0-9]*.rpm \
    /tmp/kernel-rpms/kernel-core-*.rpm \
    /tmp/kernel-rpms/kernel-modules-*.rpm \
    /tmp/kernel-rpms/kernel-devel-*.rpm

# -- Pin it --
# Any later transaction pulling a Fedora kernel would replace what the live
# payload expects, and silently change what `bootc status` reports.
dnf5 -y install dnf5-plugins
for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-devel kernel-devel-matched; do
    if rpm -q "${pkg}" >/dev/null 2>&1; then
        dnf5 versionlock add "${pkg}"
    fi
done

# -- Restore the kernel-install triggers --
pushd /usr/lib/kernel/install.d
mv -f 05-rpmostree.install.bak 05-rpmostree.install
mv -f 50-dracut.install.bak 50-dracut.install
popd

KVER="$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}')"
depmod -a "${KVER}"
