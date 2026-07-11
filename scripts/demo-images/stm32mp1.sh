#!/bin/bash
# Build the Slint demo image for the STM32MP1 (STM32MP15: DK1/DK2/EV1). Just pins
# MACHINE, the README example BOARD and its boot note; see stm32-common.sh.
set -euo pipefail

MACHINE="${MACHINE:-stm32mp1}"
BOARD="${BOARD:-stm32mp157f-dk2}"
# Apostrophe-free: an apostrophe inside a "${VAR:-default}" word still parses as a quote.
DEFAULT_BOOT_NOTE='Put your board into USB serial-boot (flashing) mode and connect its USB-C
   port to the host. On the STM32MP157F-DK2, set boot switch SW4 to
   D1=ON  D2=OFF  D3=OFF  D4=OFF. See the ST "Populate the target" guide:
     https://wiki.st.com/stm32mpu/wiki/Getting_started/STM32MP1_boards/STM32MP157x-DK2/Let%27s_start/Populate_the_target_and_boot_the_image'
BOOT_NOTE="${BOOT_NOTE:-$DEFAULT_BOOT_NOTE}"
export MACHINE BOARD BOOT_NOTE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export META_SLINT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/demo-images/common.sh
. "$SCRIPT_DIR/common.sh"
# shellcheck source=scripts/demo-images/stm32-common.sh
. "$SCRIPT_DIR/stm32-common.sh"

slint_demo_build_stm32
