#!/bin/bash
# Build the Slint demo image for the Toradex Apalis iMX8. Just pins MACHINE, the board
# description and the GPU stack; see toradex-common.sh.
set -euo pipefail

MACHINE="${MACHINE:-apalis-imx8}"
BOARD_DESC="${BOARD_DESC:-Toradex Apalis iMX8}"
TDX_GPU="${TDX_GPU:-vivante}"
export MACHINE BOARD_DESC TDX_GPU

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export META_SLINT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/demo-images/common.sh
. "$SCRIPT_DIR/common.sh"
# shellcheck source=scripts/demo-images/toradex-common.sh
. "$SCRIPT_DIR/toradex-common.sh"

slint_demo_build_toradex
