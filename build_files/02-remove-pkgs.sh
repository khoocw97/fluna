#!/usr/bin/env bash
#
# Removals run first, so dnf's dependency cleanup cannot take out packages we
# install later.
#
set -xeuo pipefail

echo "::group::Remove packages"
trap 'echo "::endgroup::"' EXIT

dnf5 remove -y --no-autoremove \
    gnome-keyring gnome-keyring-pam \
    firefox firefox-langpacks nvtop htop toolbox \
    ibus ibus-anthy ibus-anthy-python ibus-chewing ibus-gtk3 ibus-gtk4 \
    ibus-hangul ibus-libpinyin ibus-libs ibus-m17n ibus-setup \
    ibus-typing-booster python3-ibus

# -- Remove conflicting packages --
# mesa-va-drivers conflicts with the patched Mesa from terra-mesa (installed in
# 04-gaming). Guarded: a minimal base may not ship it.
for pkg in mesa-va-drivers; do
    if rpm -q "${pkg}" >/dev/null 2>&1; then
        dnf5 remove -y --no-autoremove "${pkg}"
    fi
done
