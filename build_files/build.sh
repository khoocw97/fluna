#!/usr/bin/env bash
#
# Stage orchestration. Keep this file boring: one line per stage, in order.
#
set -xeuo pipefail

/ctx/00-ocg-kernel.sh
/ctx/01-base.sh
/ctx/02-remove-pkgs.sh
/ctx/03-install-pkgs.sh
/ctx/04-gaming.sh
/ctx/05-script.sh
/ctx/06-finalize.sh

# After the package work: the initramfs bootc actually boots (00 shimmed
# dracut), then scratch/DNF cleanup.
/ctx/build-initramfs.sh
/ctx/cleanup.sh

# Normalize mtimes last, so the layer is reproducible.
/ctx/reset-mtimes.sh
