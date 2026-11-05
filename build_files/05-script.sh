#!/usr/bin/env bash
#
# Build-time helper scripts (extest, fonts, plymouth, firewall, ...).
# The kernel swap that used to live here is now 00-ocg-kernel.sh.
#
set -xeuo pipefail

echo "::group::Run helper scripts"
trap 'echo "::endgroup::"' EXIT

/ctx/scripts/install-extest
/ctx/scripts/install-megacmd
/ctx/scripts/install-fonts
/ctx/scripts/install-papirus
/ctx/scripts/setup-rime-build
/ctx/scripts/setup-firewall
/ctx/scripts/install-sdl-gamecontroller
/ctx/scripts/setup-plymouth-theme
