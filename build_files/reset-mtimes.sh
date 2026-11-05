#!/usr/bin/env bash
#
# Normalize filesystem timestamps so the image is reproducible.
#
set -xeuo pipefail

find /usr /etc /opt -newermt '1970-01-01T00:00:00Z' \
    -exec touch -h -a -m -d '1970-01-01T00:00:00Z' {} +
