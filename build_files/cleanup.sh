#!/usr/bin/env bash
#
# Final cleanup: scratch data, DNF state, /boot, and the rpmdb hardlink.
#
set -xeuo pipefail

echo "::group::Cleanup"
trap 'echo "::endgroup::"' EXIT

# -- Scratch data --
rm -rf /tmp/* 2>/dev/null || true
find /var -mindepth 1 -maxdepth 1 ! -name cache -exec rm -fr {} + 2>/dev/null || true
mkdir -p /var/tmp
chmod 1777 /var/tmp

# -- DNF state --
rm -f /var/log/dnf5.log 2>/dev/null || true
rm -rf /usr/lib/sysimage/libdnf5/* 2>/dev/null || true

# -- /boot is not used by bootc; the kernel lives in /usr/lib/modules --
find /boot -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true

# -- Docs/sources --
rm -rf /usr/share/doc/* /usr/src/*
rm -f /etc/profile.d/toolbox.sh

# -- rpmdb relink --
# Keep the rpm-ostree base-db in sync with the image rpmdb
# (see coreos/rpm-ostree#4554).
for file in rpmdb.sqlite rpmdb.sqlite-shm rpmdb.sqlite-wal; do
    target="/usr/share/rpm/${file}"
    link_path="/usr/lib/sysimage/rpm-ostree-base-db/${file}"
    if [[ -f "${target}" && -f "${link_path}" ]]; then
        ln -f "${target}" "${link_path}"
    fi
done
