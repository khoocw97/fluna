#!/usr/bin/env bash
#
# Initialize: overlay + repository setup/policy. Only the Terra repo bootstrap
# packages are installed here; everything else belongs to the package stage.
# The base already ships fedora, fedora-multimedia (negativo17), Cisco openh264
# and the ublue akmods COPR.
#
set -xeuo pipefail

echo "::group::Initialize"
trap 'echo "::endgroup::"' EXIT

# -- system_files --
# Read-only bind mount from the system_files stage.
cp -avf /ctx/system_files/. /

# -- COPRs (not shipped by the base) --
for copr in lizardbyte/stable lihaohong/yazi imput/helium atim/starship khoocw97/software; do
    dnf5 copr enable -y "${copr}"
done

# -- Terra (not shipped by the base) --
dnf5 install -y --nogpgcheck \
    --repofrompath="terra,https://repos.fyralabs.com/terra\$releasever" \
    terra-release terra-release-extras terra-release-mesa

dnf5 config-manager enable 'fedora-multimedia*'

# mesa: Fedora never ships it here; negativo17 stays below Terra and keeps its
# patched steam.
# kernel: versionlock in 00 already pins it, this is the fallback so a later
# transaction cannot resolve a Fedora kernel even if the lock is bypassed.
dnf5 config-manager setopt \
    "*terra*".priority=1 \
    "fedora.exclude=mesa-* kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-uki-virt" \
    "updates.exclude=mesa-* noopenh264 kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-uki-virt" \
    "updates-archive.exclude=mesa-*" \
    "fedora-multimedia.priority=4"
