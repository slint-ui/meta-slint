#!/bin/bash
# Build the Slint demo image for the Raspberry Pi 5 and collect the flashable
# artifacts into $ARTIFACT_DIR for the workflow to publish.
#
# The shared Raspberry Pi build logic lives in rpi-common.sh; this script only
# pins the target MACHINE. See rpi-common.sh for the overridable environment.
set -euo pipefail

MACHINE="${MACHINE:-raspberrypi5}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# scripts/demo-images/<this> -> repo root is two levels up.
META_SLINT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/demo-images/common.sh
. "$SCRIPT_DIR/common.sh"
# shellcheck source=scripts/demo-images/rpi-common.sh
. "$SCRIPT_DIR/rpi-common.sh"

slint_demo_build_rpi
