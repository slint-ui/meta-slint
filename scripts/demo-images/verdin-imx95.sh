#!/bin/bash
# Build the Slint demo image for the Toradex Verdin iMX95. Just pins MACHINE, the board
# description and the GPU stack; see toradex-common.sh.
set -euo pipefail

MACHINE="${MACHINE:-verdin-imx95}"
BOARD_DESC="${BOARD_DESC:-Toradex Verdin iMX95}"
TDX_GPU="${TDX_GPU:-mali}"
# Keep the module's existing (factory) bootloader: no released BSP imx-boot
# boots early Verdin iMX95 V1.1B modules (the M33 System Manager takes an
# exception before console init; verified by RAM-booting the 7.5.0, 7.6.1 and
# 7.7.0 release containers). See the TDX_DROP_BOOTLOADER block in
# toradex-common.sh; drop this once a released BSP boots those modules.
TDX_DROP_BOOTLOADER="${TDX_DROP_BOOTLOADER:-1}"
# The Verdin demo kits use the Dahlia carrier; U-Boot's built-in default is
# fdt_board=dev (the Verdin Development Board) and carriers are not
# runtime-detectable.
TDX_FDT_BOARD="${TDX_FDT_BOARD:-dahlia}"
export MACHINE BOARD_DESC TDX_GPU TDX_DROP_BOOTLOADER TDX_FDT_BOARD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export META_SLINT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/demo-images/common.sh
. "$SCRIPT_DIR/common.sh"
# shellcheck source=scripts/demo-images/toradex-common.sh
. "$SCRIPT_DIR/toradex-common.sh"

slint_demo_build_toradex
