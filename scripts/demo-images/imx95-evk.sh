#!/bin/bash
# Build the Slint demo image for the NXP i.MX95 19x19 LPDDR5 EVK. The BSP ships
# as an NXP `repo` manifest; we pin a stable imx-linux-scarthgap release.
#
# Env overrides: IMX_MANIFEST_BRANCH (imx-linux-scarthgap), IMX_MANIFEST_FILE
# (imx-6.6.52-2.2.2.xml), MACHINE, DISTRO, IMAGE, WORK_ROOT, ARTIFACT_DIR,
# SSTATE_DIR.
set -euo pipefail

IMX_MANIFEST_BRANCH="${IMX_MANIFEST_BRANCH:-imx-linux-scarthgap}"
IMX_MANIFEST_FILE="${IMX_MANIFEST_FILE:-imx-6.6.52-2.2.2.xml}"
MACHINE="${MACHINE:-imx95-19x19-lpddr5-evk}"
DISTRO="${DISTRO:-fsl-imx-wayland}"
IMAGE="${IMAGE:-imx-image-slint-demos}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_SLINT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/demo-images/common.sh
. "$SCRIPT_DIR/common.sh"

WORK_ROOT="${WORK_ROOT:-$PWD}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$WORK_ROOT/artifacts}"
export ARTIFACT_DIR
mkdir -p "$WORK_ROOT"
cd "$WORK_ROOT"

slint_demo_ensure_git_identity
slint_demo_ensure_repo_tool

# Fetch the NXP i.MX BSP via repo.
repo init -u https://github.com/nxp-imx/imx-manifest \
    -b "$IMX_MANIFEST_BRANCH" -m "$IMX_MANIFEST_FILE" --no-clone-bundle
repo sync -j"$(nproc)" --no-clone-bundle

# imx-setup-release.sh touches unset vars / returns non-zero, so relax strict
# mode; EULA=1 accepts the NXP license non-interactively. Leaves us in build/.
set +eu
EULA=1 MACHINE="$MACHINE" DISTRO="$DISTRO" source ./imx-setup-release.sh -b build
set -eu

# Add meta-clang, meta-rust-bin and meta-slint. The BSP already ships meta-clang;
# only add ours if not, to avoid a duplicate layer.
META_CLANG_DIR="$WORK_ROOT/sources/meta-clang"
if ! bitbake-layers show-layers 2>/dev/null | grep -Fq "/meta-clang"; then
    if [ ! -d "$META_CLANG_DIR" ]; then
        git clone -b scarthgap https://github.com/kraj/meta-clang.git "$META_CLANG_DIR"
    fi
    bitbake-layers add-layer "$META_CLANG_DIR"
else
    echo "meta-clang already provided by the BSP, skipping"
fi

META_RUST_BIN_DIR="$WORK_ROOT/sources/meta-rust-bin"
if ! bitbake-layers show-layers 2>/dev/null | grep -Fq "/meta-rust-bin"; then
    if [ ! -d "$META_RUST_BIN_DIR" ]; then
        git clone https://github.com/rust-embedded/meta-rust-bin.git "$META_RUST_BIN_DIR"
    fi
    bitbake-layers add-layer "$META_RUST_BIN_DIR"
else
    echo "meta-rust-bin already provided by the BSP, skipping"
fi

slint_demo_add_layer_if_missing "$META_SLINT_DIR"

slint_demo_configure_local_conf conf/local.conf

bitbake "$IMAGE"

# Ship the compressed image + its block map (bmaptool flashes the .wic.zst via
# the .bmap). Match by extension (OE adds a ".rootfs" infix); regular files only,
# so OE's symlinks don't duplicate the image.
DEPLOY="tmp/deploy/images/$MACHINE"
mapfile -t SLINT_DEMO_IMAGES < <(
    find "$DEPLOY" -maxdepth 1 -type f \( -name '*.wic.zst' -o -name '*.wic.bmap' \) | sort
)
slint_demo_collect_artifacts "${SLINT_DEMO_IMAGES[@]}"

# Flashing bundle: the boot binary for UUU (eMMC over USB) alongside the image,
# plus a README covering SD, UUU and picking the display device tree.
BOOTLOADER="$(find "$DEPLOY" -maxdepth 1 -type f -name 'imx-boot-*flash_all' | sort | head -n1 || true)"
if [ -z "$BOOTLOADER" ]; then
    BOOTLOADER="$(find "$DEPLOY" -maxdepth 1 -type f -name 'imx-boot-*sd.bin*' | sort | head -n1 || true)"
fi
if [ -n "$BOOTLOADER" ]; then
    cp -L "$BOOTLOADER" "$ARTIFACT_DIR/imx-boot-flash_all"
    IMG_NAME="$(basename "$(find "$ARTIFACT_DIR" -maxdepth 1 -name '*.wic.zst' | sort | head -n1)")"
    BMAP_NAME="$(basename "$(find "$ARTIFACT_DIR" -maxdepth 1 -name '*.wic.bmap' | sort | head -n1)")"
    WIC_NAME="${IMG_NAME%.zst}"
    cat > "$ARTIFACT_DIR/README.txt" <<EOF
Flashing the i.MX95 EVK Slint demo image
========================================

This bundle contains:
  $IMG_NAME   the demo image (compressed raw disk image)
  $BMAP_NAME  block map, for flashing with bmaptool
  imx-boot-flash_all             the i.MX boot binary, for flashing via UUU
  README.txt                     this file

The image boots into the Slint demo on the display.

Option A -- SD card
-------------------
Write $IMG_NAME to an SD/microSD card:
  * bmaptool:
      bmaptool copy --bmap $BMAP_NAME $IMG_NAME /dev/sdX
  * or decompress + dd:
      zstd -d $IMG_NAME -o $WIC_NAME
      sudo dd if=$WIC_NAME of=/dev/sdX bs=4M conv=fsync status=progress
Set the board to boot from the SD card and power on. (Replace /dev/sdX with
your card device.)

Option B -- on-board eMMC via UUU (USB)
---------------------------------------
Program the eMMC over USB with NXP's Universal Update Utility (UUU), version
1.5.220 or newer (https://github.com/nxp-imx/mfgtools/releases):
  1. Put the i.MX95 19x19 EVK into serial-download mode -- switch SW4:
         D1=ON  D2=OFF  D3=OFF  D4=OFF
  2. Connect the board's USB-C download port to the host and power on.
  3. Program the bootloader and image to eMMC (UUU decompresses the .zst):
         uuu -b emmc_all imx-boot-flash_all $IMG_NAME
  4. Power off, return SW4 to the normal boot-from-eMMC position, power on.

Display output (device tree)
----------------------------
Which display output works is decided by the selected device tree (the boot
partition ships several). If the screen stays blank, or you want a different
display path, select the matching device tree at the U-Boot prompt:
  1. Interrupt U-Boot during the boot countdown (press a key).
  2. Select the device tree, save, and reboot:
         setenv fdtfile <dtb-file>
         saveenv
         reset
On the i.MX95 19x19 EVK, HDMI is provided through an add-on bridge, each with
its own device tree -- list the exact names with 'ls mmc 1:1' in U-Boot (or
'ls /boot' on the running board):
  ...-it6263-lvds0.dtb   LVDS0 -> HDMI (IMX-LVDS-HDMI)
  ...-adv7535-...dtb     MIPI-DSI -> HDMI (IMX-MIPI-HDMI)

See the i.MX Linux User's Guide (UG10163) for details:
https://www.nxp.com/docs/en/user-guide/UG10163.pdf
EOF
    echo "Added flashing files: $(basename "$BOOTLOADER") -> imx-boot-flash_all, README.txt"
else
    echo "warning: no imx-boot bootloader found under $DEPLOY; skipping flashing files" >&2
fi
