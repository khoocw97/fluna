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
  Example: the `sddm-themes` RPM owns `/usr/share/sddm/themes/simple-sddm/*`, so
  the repo keeps the editable `theme.conf` under `/etc` and symlinks it in
  `06-finalize.sh`. Use a finalize step only for this case, with a comment.
- Never write `/usr/etc`; `bootc container lint` rejects it.
- `/var` in the image is like `VOLUME /var`: content is unpacked only on first
  install, later image changes are ignored. Create runtime state dirs with
  `tmpfiles.d` in `system_files/usr/lib/tmpfiles.d/`, never with `mkdir` in the
  build.
- Kernel args: `system_files/usr/lib/bootc/kargs.d/*.toml`. `10-plymouth.toml`
  ships the active `rhgb quiet`; `11-plymouth-sddm.toml` documents (commented
  out) the `vt.*`/`fbcon` args SDDM may need for a clean Plymouth hand-off.
  Leave them disabled while greetd is the display manager.
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
- SDDM + `simple-sddm` stay installed as a fallback and are **not** enabled.
  Fedora's `85-display-manager.preset` (redhat-systemd-presets-common) enables
  every installed DM ("the one installed first wins"), so installing `sddm`
  creates `display-manager.service -> sddm.service`; `06-finalize` must
  `systemctl disable sddm` before `systemctl enable greetd`. `greetd` is not in
  that preset, hence the explicit enable. If sddm is removed entirely, drop the
  `disable sddm` line too (it fails once the unit is gone); with several DMs
  installed, use `systemctl enable --force greetd` to take over the alias.
  Switch back with `systemctl enable sddm && systemctl disable greetd`.
- Do not reintroduce `sddm.service.d/10-plymouth.conf`
  (`Conflicts=plymouth-quit` + `sleep 3` + `plymouth quit --retain-splash`):
  it quits Plymouth after Weston already owns DRM master, which blanked the
  machine. SDDM has no Plymouth handoff at all; GDM is the only DM with one
  built in (ArchWiki Plymouth: "GDM supports smooth transition out of the box").
- Live ISO autologin lives in `installer/src/livesys-umbriel` via greetd's
  `[initial_session]`.

## Checks

- `bash -n` on touched scripts; parse TOML with `python3 -c 'import tomllib'`.
- `bootc container lint` runs at the end of the image build; keep it clean.
- Verify COPR package names against `/var/home/weng/Project/fedora-copr/*.spec`
  and the `fedora-45-x86_64` repo of `khoocw97/software`.
