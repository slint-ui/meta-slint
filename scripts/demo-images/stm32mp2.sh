#!/bin/bash
# Build the Slint demo image for the STM32MP2 (STM32MP25: e.g. STM32MP257F-DK).
# Just pins MACHINE, the README example BOARD and its boot note; see
# stm32-common.sh. The boot demo (home-automation here) is set in the bbappend.
set -euo pipefail

MACHINE="${MACHINE:-stm32mp2}"
BOARD="${BOARD:-stm32mp257f-dk}"
# Apostrophe-free: an apostrophe inside a "${VAR:-default}" word still parses as a quote.
DEFAULT_BOOT_NOTE='Put your board into USB serial-boot (flashing) mode and connect its USB-C
   port to the host. On the STM32MP257F-DK, set the boot-mode switches to the
   serial-boot (DFU) position; see the ST "Populate the target" guide for the
   exact switch settings for your board:
     https://wiki.st.com/stm32mpu/wiki/Getting_started/STM32MP2_boards/STM32MP257x-DK/Let%27s_start/Populate_the_target_and_boot_the_image'
BOOT_NOTE="${BOOT_NOTE:-$DEFAULT_BOOT_NOTE}"
export MACHINE BOARD BOOT_NOTE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export META_SLINT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/demo-images/common.sh
. "$SCRIPT_DIR/common.sh"
# shellcheck source=scripts/demo-images/stm32-common.sh
. "$SCRIPT_DIR/stm32-common.sh"

slint_demo_build_stm32
