#!/bin/bash
# Build the Slint demo image for the TI Sitara AM62Px (SK-AM62P-LP). Just pins
# MACHINE and the board description; see ti-common.sh.
set -euo pipefail

MACHINE="${MACHINE:-am62pxx-evm}"
BOARD_DESC="${BOARD_DESC:-TI SK-AM62P-LP (AM62Px)}"
export MACHINE BOARD_DESC

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export META_SLINT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/demo-images/common.sh
. "$SCRIPT_DIR/common.sh"
# shellcheck source=scripts/demo-images/ti-common.sh
. "$SCRIPT_DIR/ti-common.sh"

slint_demo_build_ti
