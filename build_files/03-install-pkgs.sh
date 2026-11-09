#!/usr/bin/env bash
#
# Packages (everything that is not gaming). Grouped by purpose so a diff shows
# what changed.
#
set -xeuo pipefail

echo "::group::Install packages"
trap 'echo "::endgroup::"' EXIT

# -- Fonts (weak deps off) --
dnf5 install -y --setopt=install_weak_deps=False \
    default-fonts-core-emoji default-fonts default-fonts-cjk-sans \
    google-noto-color-emoji-fonts google-noto-emoji-fonts \
    google-noto-sans-cjk-vf-fonts fira-code-fonts glibc-all-langpacks \
    langpacks-fonts-zh_CN langpacks-fonts-zh_TW

# -- Window manager (umbriel from khoocw97/software) --
dnf5 install -y umbriel noctalia

# -- Personal packages --
dnf5 install -y \
    starship sddm qt6-qtdeclarative sddm-themes \
    gnome-keyring-pam adw-gtk3-theme xdg-user-dirs power-profiles-daemon \
    fuzzel bibata-cursor-themes meld helium-bin sunshine kitty yazi nemo \
    kdeconnectd kf6-qqc2-desktop-style udiskie swayimg vm-curator

# -- CLI tools --
dnf5 install -y \
    ripgrep fd-find chezmoi zoxide eza fzf bat tealdeer fastfetch duf \
    btop brightnessctl playerctl

# -- Input: fcitx5 (replaces ibus) --
dnf5 install -y \
    fcitx5 fcitx5-rime librime-lua librime-octagram \
    fcitx5-gtk fcitx5-qt fcitx5-configtool

# -- Virtualization --
dnf5 install -y libvirt qemu-kvm swtpm swtpm-tools edk2-ovmf dnsmasq

# -- Editor + AI coding agent (Terra) --
dnf5 install -y zed opencode

# -- Codecs --
dnf5 install -y libfreeaptx
dnf5 install -y --allowerasing openh264.x86_64 openh264.i686
dnf5 install -y libbluray libbluray-utils
