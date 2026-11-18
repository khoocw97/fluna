#!/usr/bin/env bash
#
# Last build stage: cleanup, system configuration, third-party repos off, ujust.
#
set -xeuo pipefail

echo "::group::Finalize build"
trap 'echo "::endgroup::"' EXIT

# -- Basic cleanup --
rm -f /etc/profile.d/toolbox.sh
mkdir -p /var/tmp
chmod 1777 /var/tmp

# -- Bluetooth input --
# Lets controllers work as HID devices over Bluetooth.
if [[ -f /etc/bluetooth/input.conf ]]; then
    sed -i 's/#UserspaceHID.*/UserspaceHID=true/' /etc/bluetooth/input.conf
fi

# -- PulseAudio stub --
# Some launchers and older games still probe for a pulseaudio binary.
[[ -e /usr/bin/pulseaudio ]] || ln -s /usr/bin/true /usr/bin/pulseaudio

# -- Flathub repo file --
# The base image's flatpak-add-fedora-repos.service reads this exact path.
mkdir -p /etc/flatpak/remotes.d
curl -f --retry 3 --retry-all-errors \
    -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo \
    https://dl.flathub.org/repo/flathub.flatpakrepo

# -- ujust recipes --
# One installed file per recipe file (instead of concatenating into
# 60-custom.just), so a recipe can be traced back to its source file.
# 07-finalize.sh appends the matching `import` lines to the base justfile.
install -d /usr/share/ublue-os/just
# The base image's justfile imports 60-custom.just by name; keep an empty file
# so that import keeps resolving. Our recipes are imported by 07-finalize.sh.
touch /usr/share/ublue-os/just/60-custom.just
for f in /ctx/ujust/common/*.just; do
    install -m 0644 "${f}" "/usr/share/ublue-os/just/60-fluna-$(basename "${f}")"
done
for f in /ctx/ujust/gaming/*.just; do
    install -m 0644 "${f}" "/usr/share/ublue-os/just/61-fluna-$(basename "${f}")"
done

# -- ujust imports --
shopt -s nullglob
for f in /usr/share/ublue-os/just/6[01]-fluna-*.just; do
    grep -qxF "import \"${f}\"" /usr/share/ublue-os/justfile || \
        echo "import \"${f}\"" >> /usr/share/ublue-os/justfile
done

# -- System configuration --
# sddm theme config lives in /etc so users can edit it.
ln -sf /etc/sddm/themes/simple-sddm/theme.conf /usr/share/sddm/themes/simple-sddm/theme.conf

systemctl set-default graphical.target

# -- Container image signature policy --
# bootc only verifies an image when containers-policy.json has an entry for it
# AND the deployment was switched with --enforce-container-sigpolicy. The base
# already ships a policy with `reject` as default and an accept-anything
# catch-all, so only fluna's own entry is added.
install -Dm644 /ctx/cosign.pub /etc/pki/containers/fluna.pub
policy=/etc/containers/policy.json
if [[ ! -f ${policy} ]]; then
    echo '{"default":[{"type":"reject"}],"transports":{"docker":{}}}' > "${policy}"
fi
jq --arg repo ghcr.io/khoocw97/fluna '
    .transports.docker = {($repo): [{
        "type": "sigstoreSigned",
        "keyPath": "/etc/pki/containers/fluna.pub",
        "signedIdentity": {"type": "matchRepository"}
    }]} + .transports.docker
' "${policy}" > "${policy}.new"
install -m644 "${policy}.new" "${policy}"
rm -f "${policy}.new"
jq -e --arg repo ghcr.io/khoocw97/fluna \
    '.transports.docker[$repo][0].type == "sigstoreSigned"' "${policy}" > /dev/null

# -- Services --
systemctl enable podman.socket
systemctl enable flatpak-preinstall.service
# greetd + Noctalia Greeter is the login manager. SDDM stays installed as a
# fallback: `systemctl enable sddm && systemctl disable greetd` switches back.
systemctl enable greetd hide-grub.service
systemctl enable bluetooth
systemctl enable dmemcg-booster-system.service
systemctl --global enable mega-cmd-server.service steam-wrapper.service dmemcg-booster-user.service oo7-daemon.service

# -- Disable COPRs so they don't end up enabled on the final image --
for copr in lizardbyte/stable lihaohong/yazi imput/helium atim/starship khoocw97/software; do
    dnf5 copr disable -y "${copr}"
done

# -- Disable Terra --
dnf5 config-manager setopt "*terra*".enabled=false
