#!/bin/bash
# Build the Slint demo image for the Raspberry Pi 4 Model B and collect the
# flashable artifacts into $ARTIFACT_DIR for the workflow to publish.
#
# The shared Raspberry Pi build logic lives in rpi-common.sh; this script only
# pins the target MACHINE. See rpi-common.sh for the overridable environment.
#
# raspberrypi4-64 is meta-raspberrypi's 64-bit machine for the Pi 4 (and 4B);
# the Skia renderer needs a 64-bit, OpenGL-capable target.
set -euo pipefail

MACHINE="${MACHINE:-raspberrypi4-64}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# scripts/demo-images/<this> -> repo root is two levels up.
META_SLINT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/demo-images/common.sh
. "$SCRIPT_DIR/common.sh"
# shellcheck source=scripts/demo-images/rpi-common.sh
. "$SCRIPT_DIR/rpi-common.sh"

slint_demo_build_rpi
