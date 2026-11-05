#!/usr/bin/env bash
#
# Regenerate the initramfs that bootc actually boots
# (/usr/lib/modules/$kver/initramfs.img, not /boot/initramfs-*.img).
#
set -xeuo pipefail

echo "::group::Build initramfs"
trap 'echo "::endgroup::"' EXIT

# Longer plymouth timeout for slow devices (theme installed in 05-script.sh).
if [[ -f /usr/share/plymouth/plymouthd.defaults ]]; then
    sed -i 's/^DeviceTimeout=.*/DeviceTimeout=15/' /usr/share/plymouth/plymouthd.defaults
fi

for kver in $(ls /usr/lib/modules); do
    DRACUT_NO_XATTR=1 dracut \
        --no-hostonly \
        --kver "${kver}" \
        --reproducible \
        --zstd \
        --add ostree \
        --force \
        "/usr/lib/modules/${kver}/initramfs.img"
    chmod 0600 "/usr/lib/modules/${kver}/initramfs.img"
done
