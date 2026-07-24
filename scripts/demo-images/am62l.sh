#!/bin/bash
# Build the Slint demo image for the TI Sitara AM62L EVM (TMDS62LEVM). Same SDK
# and flow as the AM62Px build (see ti-common.sh), but the AM62L has no GPU:
# Slint's Skia renderer still builds with GL (it always links it), yet renders
# in software at runtime, and the proprietary Imagination GPU driver is left out.
set -euo pipefail

MACHINE="${MACHINE:-am62lxx-evm}"
BOARD_DESC="${BOARD_DESC:-TI AM62L EVM (TMDS62LEVM)}"
# No GPU: don't pull the proprietary Imagination DDK. The recipes select Skia's
# software raster at runtime (SLINT_BACKEND=linuxkms-skia-software) for this
# machine; nothing else differs from the AM62Px build.
TI_GPU="${TI_GPU:-0}"
export MACHINE BOARD_DESC TI_GPU

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export META_SLINT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/demo-images/common.sh
. "$SCRIPT_DIR/common.sh"
# shellcheck source=scripts/demo-images/ti-common.sh
. "$SCRIPT_DIR/ti-common.sh"

slint_demo_build_ti
