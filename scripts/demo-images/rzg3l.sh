#!/bin/bash
# Build the Slint demo image for the Renesas RZ/G3L SMARC EVK. The BSP fetching,
# configuration and packaging are shared with the other RZ boards (rz-common.sh);
# this wrapper only carries the pins.
#
# The G3L is on a different BSP line from the G3E: it ships as "RZ Linux BSP
# Plus" (kernel 6.12), so it has its own meta-renesas tag, its own poky/meta-oe
# revisions and its own conf template (bsp-plus-conf rather than rz-conf). The
# pins below are the ones Renesas tested it with, from the G3L tab of
# https://renesas-rz.github.io/rz_linux_bsp_plus/RZG/how_to_build_linux_bsp_plus/
#
# Only the graphics package is fetched, not the video codec one: the demos don't
# use hardware video decode, and meta-rz-features/meta-rz-codecs would be a
# second licence-gated download.
set -euo pipefail

MACHINE="${MACHINE:-smarc-rzg3l}"
DISTRO="${DISTRO:-rz-vlp}"
IMAGE="${IMAGE:-core-image-slint-demos}"
BOARD_DESC="${BOARD_DESC:-Renesas RZ/G3L SMARC EVK}"

# Pinned BSP revisions -- from the BSP Plus page for this tag; keep them together.
META_RENESAS_TAG="${META_RENESAS_TAG:-RZG3L-BSP-1.0.0}"
POKY_REV="${POKY_REV:-7e8674996b0164b07e56bc066d0fba790e627061}"          # scarthgap HEAD
META_ARM_REV="${META_ARM_REV:-8e0f8af90fefb03f08cd2228cde7a89902a6b37c}"  # scarthgap
META_OE_REV="${META_OE_REV:-89a01c3d9ad1f8fce6aeb4dd0e694cfa28d42099}"    # scarthgap
TEMPLATECONF_SUBDIR="${TEMPLATECONF_SUBDIR:-meta-rz-distro/conf/templates/bsp-plus-conf/}"

# Proprietary graphics package (fetched from the internal mirror, see above).
# Renesas ships it inside RTK0EF0045Z14001ZJ-*.zip; the mirror holds the inner
# tarball, which is what the BSP Plus instructions extract.
GRAPHICS_ARCHIVE="${GRAPHICS_ARCHIVE:-meta-rz-features-5.1.3.2.tar.gz}"
GRAPHICS_SHA256="${GRAPHICS_SHA256:-3c23544e7c1b95993b7d5d4e5064d64d5a4122b998ec4706f0f01c168983cbda}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_SLINT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/demo-images/common.sh
. "$SCRIPT_DIR/common.sh"
# shellcheck source=scripts/demo-images/rz-common.sh
. "$SCRIPT_DIR/rz-common.sh"

slint_demo_build_rz
