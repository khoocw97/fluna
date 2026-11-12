# fluna

A personal [bootc](https://github.com/bootc-dev/bootc) image built on Universal Blue's
[`base-main`](https://github.com/ublue-os/base-main) (Fedora 45), with
[Umbriel](https://github.com/noctalia-dev/umbriel) + [Noctalia](https://github.com/noctalia-dev/noctalia). 

Published at: `ghcr.io/khoocw97/fluna:latest`

## What's in the image

- **Kernel** — [Open Gaming Collective kernel](https://github.com/OpenGamingCollective/kernel-packages-fedora)
  from `ghcr.io/ublue-os/akmods:ogc-45`.
- **Compositor/Shell** — [Umbriel](https://github.com/noctalia-dev/umbriel) and [Noctalia](https://github.com/noctalia-dev/noctalia)
- **Login** — SDDM with the `simple-sddm` theme
- **Input** — `fcitx5` + `fcitx5-rime`, replacing ibus. `rime-ice` is built into
  `/usr/share/rime-ice` at image build time; `ujust setup-rime` installs it into
  `~/.local/share/fcitx5/rime` (full pinyin or double pinyin). US layout is the default,
  Rime is the default input method.
- **Apps** — kitty, nemo, Helium, Zed, OpenCode, yazi, fuzzel, starship, fastfetch, btop,
  meld, swayimg, Sunshine, KDE Connect, MEGAcmd, Bibata cursors, adw-gtk3 and Papirus icons.
- **Gaming (Bazzite-style)** — Terra's patched Mesa, Xwayland, wireplumber and BlueZ,
  plus gamescope, mangohud, Steam, `dmemcg`, `vulkan-low-latency-layer`, extest and the
  SDL GameControllerDB. `ujust lsfg-vk` installs LSFG-VK frame generation.
- **Virtualization** — libvirt/QEMU, swtpm, OVMF, vm-curator and a set of distrobox
  definitions (`/etc/distrobox/distrobox.ini`). `ujust setup-virtualization` enables the
  modular libvirt daemons, KVM args, SPICE USB hotplug and the `libvirt` group.

All package installation lives in [`build_files/`](./build_files), split into numbered
stages and called from [`build_files/build.sh`](./build_files/build.sh).

Default Umbriel keybinds worth knowing (full list in
`/etc/skel/.config/umbriel/cfg/keybinds.toml`):

## Switching to this image

From a system already running a bootc image (Fedora Atomic, Bazzite, Bluefin, Aurora, ...):

```bash
sudo bootc switch ghcr.io/khoocw97/fluna:latest
```

Reboot to apply.

### Secure Boot

The fluna kernel is signed with Universal Blue's akmods key, not Fedora's. The installer
queues that key for enrollment (`mokutil --import`), so the first boot after installing
shows the MOK manager:

1. Select **Enroll MOK**, then **Continue**.
2. Enter `universalblue` as the password.
3. Reboot.

If you enabled Secure Boot after installing, or switched to fluna with `bootc switch` on a
system that does not already trust Universal Blue's key, run:

```bash
ujust enroll-secure-boot-key
```

and repeat the MOK steps. Images that already come from Universal Blue already have the key 
enrolled.

## Credits

This repository started from [ublue-os/image-template](https://github.com/ublue-os/image-template).
The gaming stack and installer follow [Bazzite](https://github.com/ublue-os/bazzite)'s approach.
