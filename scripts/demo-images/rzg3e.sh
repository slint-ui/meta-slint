#!/bin/bash
# Build the Slint demo image for the Renesas RZ/G3E SMARC EVK. The BSP fetching,
# configuration and packaging are shared with the other RZ boards (rz-common.sh);
# this wrapper only carries the pins.
#
# The proprietary graphics package comes from an internal mirror -- see
# rz-common.sh for how its URL is passed in (GRAPHICS_URL / GRAPHICS_URL_FILE).
set -euo pipefail

MACHINE="${MACHINE:-smarc-rzg3e}"
DISTRO="${DISTRO:-rz-vlp}"
IMAGE="${IMAGE:-core-image-slint-demos}"
BOARD_DESC="${BOARD_DESC:-Renesas RZ/G3E SMARC EVK}"

# Pinned BSP revisions -- from Renesas' README for this tag; keep them together.
META_RENESAS_TAG="${META_RENESAS_TAG:-RZG3E-BSP-1.0.0}"
POKY_REV="${POKY_REV:-dc4827b3660bc1a03a2bc3b0672615b50e9137ff}"          # scarthgap-5.0.8
META_ARM_REV="${META_ARM_REV:-950a4afce46a359def2958bd9ae33fc08ff9bb0d}"  # yocto-5.0.1
META_OE_REV="${META_OE_REV:-67ad83dd7c2485dae0c90eac345007af6195b84d}"    # scarthgap HEAD
TEMPLATECONF_SUBDIR="${TEMPLATECONF_SUBDIR:-meta-rz-distro/conf/templates/rz-conf/}"

# Proprietary graphics package (fetched from the internal mirror, see above).
GRAPHICS_ARCHIVE="${GRAPHICS_ARCHIVE:-meta-rz-features_graphics_v4.2.0.2.tar.gz}"
GRAPHICS_SHA256="${GRAPHICS_SHA256:-37118a4f103b79c748fea6ba4d013d8c4a1807137a54f83be668235206a5ad22}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_SLINT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/demo-images/common.sh
. "$SCRIPT_DIR/common.sh"
# shellcheck source=scripts/demo-images/rz-common.sh
. "$SCRIPT_DIR/rz-common.sh"

slint_demo_build_rz
