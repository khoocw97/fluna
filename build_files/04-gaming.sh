#!/usr/bin/env bash
#
# Gaming: patched Mesa/Xwayland/wireplumber/BlueZ plus gamescope, mangohud and
# Steam.
#
set -xeuo pipefail

echo "::group::Install gaming stack"
trap 'echo "::endgroup::"' EXIT

# -- Conflicts with the patched audio stack --
if rpm -q pipewire-config-raop >/dev/null 2>&1; then
    dnf5 remove -y --no-autoremove pipewire-config-raop
fi

# -- Patched Mesa (terra-mesa) --
# mesa-filesystem carries the versioned deps that pull the rest of the stack.
dnf5 swap -y --from-repo=terra-mesa mesa-filesystem mesa-filesystem
dnf5 install -y mesa-libEGL.i686 intel-opencl clinfo

# -- Patched Xwayland / wireplumber / BlueZ (terra-extras) --
dnf5 swap -y --allowerasing --from-repo=terra-extras \
    xorg-x11-server-Xwayland terra-xorg-x11-server-Xwayland
dnf5 swap -y --allowerasing --from-repo=terra-extras \
    wireplumber terra-wireplumber
dnf5 install -y --allowerasing --from-repo=terra-extras \
    terra-bluez terra-bluez-libs terra-bluez-obexd terra-bluez-cups

# -- dmemcg --
# Memory reclaim booster; obsoletes the stock uresourced.
dnf5 install -y --allowerasing --from-repo=terra-extras uresourced-dmemcg
dnf5 install -y dmemcg-booster

# -- Patched gamescope/mangohud --
dnf5 install -y --allowerasing --from-repo=terra-extras \
    terra-gamescope terra-gamescope-libs terra-gamescope-libs.i686 \
    terra-mangohud terra-mangohud.i686

# -- Vulkan + Steam --
dnf5 install -y vulkan-tools vulkan-low-latency-layer
dnf5 install -y --setopt=install_weak_deps=False steam

# Feral gamemode is redundant with the gamescope/dmemcg stack.
if rpm -q gamemode >/dev/null 2>&1; then
    dnf5 remove -y --no-autoremove gamemode
fi

# -- Pin the patched stack --
# A later transaction must not swap these back to the Fedora builds.
for pkg in \
    mesa-dri-drivers mesa-filesystem mesa-libEGL mesa-libGL mesa-libgbm mesa-vulkan-drivers \
    terra-xorg-x11-server-Xwayland terra-wireplumber terra-bluez \
    terra-gamescope terra-mangohud; do
    if rpm -q "${pkg}" >/dev/null 2>&1; then
        dnf5 versionlock add "${pkg}"
    fi
done
