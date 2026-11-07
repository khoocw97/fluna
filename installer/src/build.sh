#!/usr/bin/bash
# Live/installer ISO payload build. Runs INSIDE the payload image build
# (privileged) with the build context bind-mounted at /src.
#
# Structure follows ublue-os/bazzite installer/build.sh: all logic lives here so
# the Containerfile stays a single RUN. fluna-specific: the live session runs
# umbriel (custom livesys session, see livesys-umbriel) with Anaconda
# autostarted from it.
set -exo pipefail
{ export PS4='+( ${BASH_SOURCE}:${LINENO} ): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'; } 2>/dev/null

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_IMAGE=${BASE_IMAGE:?}
INSTALL_IMAGE_PAYLOAD=${INSTALL_IMAGE_PAYLOAD:?}

# /root is a symlink on these images; make sure its target exists.
mkdir -p "$(realpath /root)"

# bwrap (dnf scriptlets) tries to write /proc/sys/user/max_user_namespaces,
# which is mounted read-only in the build container.
mount -o remount,rw /proc/sys

# Embed the image to install so the live ISO can install fully offline.
if mountpoint -q /usr/lib/containers/storage; then
    # Reuse the image already in the host's container storage (bootc hosts).
    podman save --format oci-archive "$INSTALL_IMAGE_PAYLOAD" |
        podman load --storage-opt additionalimagestore=''
else
    podman pull "$INSTALL_IMAGE_PAYLOAD"
fi

# Secure Boot: swap the ogc kernel for a vanilla Fedora-signed one so the live
# ISO boots SB-on anywhere. Must run BEFORE the dracut regen below. The
# installed system is unaffected (the payload keeps fluna's own kernel).
"$SCRIPT_DIR/titanoboa_hook_preinitramfs.sh"

# Live initramfs: add the dmsquash-live modules so the ISO can mount its
# squashfs as the live root. Without this the ISO boots but finds no root.
dnf install -y dracut-live jq
kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version')
DRACUT_NO_XATTR=1 dracut -v --force --zstd --reproducible --no-hostonly \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

# Live session: livesys-scripts has no umbriel session, install ours.
dnf install -y livesys-scripts
install -Dm755 "$SCRIPT_DIR/livesys-umbriel" /usr/libexec/livesys/sessions.d/livesys-umbriel
sed -i 's/^livesys_session=.*/livesys_session="umbriel"/' /etc/sysconfig/livesys
systemctl enable livesys.service livesys-late.service

# Anaconda + a kickstart that installs fluna from the embedded image
# (containers-storage transport = offline). This is the actual install path.
# Versionlocks only pin the shipped image; clear them so depsolve is free.
dnf -qy versionlock clear
dnf install -y --allowerasing \
    anaconda-live libblockdev-btrfs libblockdev-lvm dm mokutil

# Anaconda defaults to a 6-character password policy, and the F44 Web UI
# (anaconda-webui 68) hard-blocks Next until the length rule is met. Allow
# 1-character root/user/LUKS passwords in the installer.
sed -i -E '/^[[:space:]]*(root|user|luks) \(quality [0-9]+, length [0-9]+/ s/length [0-9]+/length 1/' \
    /etc/anaconda/anaconda.conf
[[ $(grep -cE '^[[:space:]]*(root|user|luks) \(quality [0-9]+, length 1' /etc/anaconda/anaconda.conf) -eq 3 ]] || {
    echo >&2 "ERROR: could not lower the Anaconda password policy"
    exit 1
}
mkdir -p /var/lib/rpm-state # Anaconda Web UI needs this
# --leavebootorder: anaconda's ostree path runs
# `bootupctl backend install --update-firmware`, whose efibootmgr call fails on
# many firmwares and in VMs ("Cannot allocate memory" = NVRAM full) and aborts
# the install with "failed to write boot loader configuration". This drops
# --update-firmware; the %post below writes the EFI entry best-effort instead.
cat >>/usr/share/anaconda/interactive-defaults.ks <<EOF

ostreecontainer --url=${INSTALL_IMAGE_PAYLOAD} --transport=containers-storage --no-signature-verification
bootloader --leavebootorder
EOF

# Secure Boot: queue Universal Blue's kernel-signing key for enrollment so the
# installed ogc kernel boots with SB on. mokutil --import writes the MokNew EFI
# variable (firmware state), so running it from the live session is enough — the
# MOK manager prompts on the next boot. Same mechanism bazzite uses.
SECUREBOOT_KEY=/etc/pki/akmods/certs/akmods-ublue.der
[[ -f ${SECUREBOOT_KEY} ]] || {
    echo >&2 "ERROR: ${SECUREBOOT_KEY} missing; the installed kernel's key cannot be enrolled"
    exit 1
}
cat >>/usr/share/anaconda/interactive-defaults.ks <<EOF

%post --nochroot --log=/tmp/installer-secureboot.log
if [ -d /sys/firmware/efi ] && [ -f ${SECUREBOOT_KEY} ]; then
    mokutil --timeout -1 || :
    printf 'universalblue\nuniversalblue\n' | mokutil --import ${SECUREBOOT_KEY} || :
fi
%end
EOF

# bootupd no longer touches NVRAM (see --leavebootorder above), so add the EFI
# boot entry here. If efibootmgr fails, keep a removable-media boot path.
cat >>/usr/share/anaconda/interactive-defaults.ks <<'EOF'

%post --nochroot --log=/tmp/installer-efi.log
if [ -d /sys/firmware/efi ] && [ -d /mnt/sysroot/boot/efi/EFI/fedora ]; then
    root_src=$(findmnt -no SOURCE /mnt/sysroot)
    disk=/dev/$(lsblk -no PKNAME "${root_src%%[*}")
    esp=$(lsblk -no PARTN,FSTYPE "$disk" | awk '$2 == "vfat" { print $1; exit }')
    efibootmgr -c -d "$disk" -p "$esp" -L fluna -l '\EFI\fedora\shimx64.efi' ||
        cp -f /mnt/sysroot/boot/efi/EFI/fedora/grubx64.efi /mnt/sysroot/boot/efi/EFI/BOOT/ ||
        :
fi
%end
EOF

# image-builder needs gcdx64.efi and expects the EFI directory in /boot/efi.
dnf install -y grub2-efi-x64-cdboot
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/
cp -v /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi

# Set the timezone to UTC.
rm -f /etc/localtime
systemd-firstboot --timezone UTC

# / in a booted live ISO is an overlayfs whose upperdir lives under /run, so
# /var/tmp is on a small tmpfs. ostree needs much more room there for the
# install, so mount a larger tmpfs over it at boot.
rm -rf /var/tmp
mkdir -p /var/tmp
cat >/etc/systemd/system/var-tmp.mount <<'EOF'
[Unit]
Description=Larger tmpfs for /var/tmp on live system

[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=size=50%%,nr_inodes=1m,x-systemd.graceful-option=usrquota

[Install]
WantedBy=local-fs.target
EOF
systemctl enable var-tmp.mount

# /var/lib/flatpak read-only: keeps the live session's flatpak downloads out of
# the install, and the installed system gets its flatpaks from the image.
mkdir -p /var/lib/flatpak
cat >/etc/systemd/system/var-lib-flatpak.mount <<'EOF'
[Mount]
Type=none
What=/var/lib/flatpak
Where=/var/lib/flatpak
Options=bind,ro

[Install]
WantedBy=multi-user.target
EOF
systemctl enable var-lib-flatpak.mount

# The ISO config titanoboa requires at this exact path.
mkdir -p /usr/lib/bootc-image-builder
cp "$SCRIPT_DIR/iso.yaml" /usr/lib/bootc-image-builder/iso.yaml

# Clean up dnf cache to save space.
dnf clean all
