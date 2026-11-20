#!/usr/bin/env bash
#
# Build-time helper scripts
#
set -xeuo pipefail

echo "::group::Run helper scripts"
trap 'echo "::endgroup::"' EXIT

/ctx/scripts/install-extest
/ctx/scripts/install-megacmd
/ctx/scripts/install-papirus
/ctx/scripts/setup-firewall
/ctx/scripts/install-sdl-gamecontroller
/ctx/scripts/setup-plymouth-theme
