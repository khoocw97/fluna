# AGENTS.md

Conventions for this repo. Read before touching `build_files/` or
`system_files/`.

Layout follows [ublue-os/image-template](https://github.com/ublue-os/image-template);
filesystem rules follow [bootc](https://bootc.dev/bootc/).

## Build shape

- `Containerfile` has a `ctx` stage (`build_files` → `/`, `system_files` →
  `/system_files`, `ujust` → `/ujust`) and one build stage that runs
  `/ctx/build.sh` with `ctx` mounted at `/ctx`.
- `build_files/NN-*.sh` are stages, run in order by `build.sh`:
  `00` kernel → `01` base (+ copy `system_files`, enable COPRs) → `02` removals
  → `03` packages → `04` gaming → `05` helper scripts → `06` finalize, then
  initramfs, cleanup, reset-mtimes.
- `system_files/` is a plain mirror of `/`. **Finished image files go there,
  nowhere else.**
- `installer/`, `disk_config/`, `iso*.toml` describe the live ISO payload, not
  the installed OS.

## File placement (bootc)

- `system_files/` is copied to `/` in `01-base.sh`, **before any `dnf install`**.
  Put the final file there and stop. Do not copy/`install` it again in
  `06-finalize.sh`: packaged `/etc` files are `%config(noreplace)`, so RPM keeps
  our copy (and leaves an `.rpmnew` of the packaged default). Re-copying is dead
  code.
  Check a package's flags with
  `rpm -qp --qf '[%{fileflags:fflags} %{filenames}\n]' foo.rpm` (`cn` = noreplace).
- Regular (non-`%config`) files owned by an RPM **are** replaced by the package.
  There is no `/etc` override for such paths: patch the installed file in
  `06-finalize.sh` after the package step, with a comment and a `grep -qx`
  check that the patch applied. Live example: `Exec=` in
  `/usr/share/wayland-sessions/umbriel.desktop` (owned by `umbriel`).
- Never write `/usr/etc`; `bootc container lint` rejects it.
- Never write `/usr/local/*` either: on Fedora it is a symlink to
  `/var/usrlocal`, and image `/var` content is only applied on first install
  (see next bullet). Ship image binaries in `/usr/bin` instead.
- `/var` in the image is like `VOLUME /var`: content is unpacked only on first
  install, later image changes are ignored. Create runtime state dirs with
  `tmpfiles.d` in `system_files/usr/lib/tmpfiles.d/`, never with `mkdir` in the
  build.
- Kernel args: `system_files/usr/lib/bootc/kargs.d/*.toml`. `10-plymouth.toml`
  ships `rhgb quiet`. Every `*.toml` there must contain a `kargs` field — lint
  rejects even a fully commented-out file.
- Units: `system_files/usr/lib/systemd/system/` (e.g. `hide-grub.service`),
  enabled with `systemctl enable` in `06-finalize.sh`.

## Login stack

- Display manager is `greetd` + `noctalia-greeter-git` (COPR
  `khoocw97/software`, installed with the window-manager packages in `03`).
  `greetd.service` is `After=plymouth-quit-wait.service`, so Plymouth is fully
  gone before the greeter repaints.
- `system_files/etc/greetd/config.toml`:
  `command = /usr/bin/noctalia-greeter-session`, `user = "greetd"` (Fedora's
  greetd account; the upstream docs' `greeter` user does not exist here).
- Greeter state dir:
  `system_files/usr/lib/tmpfiles.d/noctalia-greeter.conf`
  (`/var/lib/noctalia-greeter 0750 greetd greetd`). The RPM ships no rule, and
  upstream's rule hardcodes `greeter:greeter`.
- The greeter gets DRM/seat access through `pam_systemd`, already present in
  Fedora's `greetd-greeter` PAM service; no `video`/`input` group changes.
- No other display manager is installed. Fedora's `85-display-manager.preset`
  (redhat-systemd-presets-common) enables every installed DM ("the one installed
  first wins"), so installing any DM (gdm, sddm, plasmalogin, ...) grabs
  `display-manager.service` and it must be `systemctl disable`d before
  `systemctl enable greetd`. `greetd` is not in that preset, hence the explicit
  enable; with several DMs present, `systemctl enable --force greetd`.
- Never hand Plymouth off from a display-manager unit (`Conflicts=plymouth-quit`
  + `sleep` + `plymouth quit --retain-splash`): by then the DM's compositor
  already owns DRM master and the machine blanks. GDM is the only DM with a
  working hand-off built in; greetd instead starts
  `After=plymouth-quit-wait.service`, which is why it needs nothing.
- Session start cannot be seamless: greetd sets the VT back to text mode
  (`kd_setmode(KdMode::Text)`) and writes a clear to it before exec'ing the
  session, and on Fedora's kernel
  (`CONFIG_FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER=y`) any write to the VT makes
  fbcon take over and modeset every output. Anything the session prints then
  lands on the console, so the hand-off showed a terminal instead of a clean
  switch. `06-finalize` rewrites `Exec=` in
  `/usr/share/wayland-sessions/umbriel.desktop` to
  `system_files/usr/bin/umbriel-session`, which clears the VT
  (`ESC[2J ESC[H ESC[3J ESC[?25l`) and runs `start-umbriel` under
  `systemd-cat -t umbriel-session` so its stdio goes to the journal, never to
  the VT. Same approach as dux-greeter#46 / dux-shell `5b41d69`.
- Live ISO autologin lives in `installer/src/livesys-umbriel` via greetd's
  `[initial_session]` (also through `umbriel-session`).

## Checks

- `bash -n` on touched scripts; parse TOML with `python3 -c 'import tomllib'`.
- `bootc container lint` runs at the end of the image build; keep it clean.
- Verify COPR package names against `/var/home/weng/Project/fedora-copr/*.spec`
  and the `fedora-45-x86_64` repo of `khoocw97/software`.
