#!/bin/bash
# Build the Slint demo image for the PHYTEC phyBOARD-Polis i.MX 8M Mini Kit.
# PHYTEC ships the BSP as a `repo` manifest fetched via their phyLinux tool; we
# pin a stable scarthgap release. The i.MX 8M Mini has a Vivante GC NanoUltra
# GPU, so the demos render on the GPU (EGL/GLES via imx-gpu-viv), like the other
# i.MX board.
#
# Env overrides: PHYTEC_RELEASE, MACHINE, DISTRO, IMAGE, WORK_ROOT, ARTIFACT_DIR,
# SSTATE_DIR.
set -euo pipefail

PHYTEC_RELEASE="${PHYTEC_RELEASE:-BSP-Yocto-NXP-i.MX8MM-PD25.1.1}"
MACHINE="${MACHINE:-phyboard-polis-imx8mm-5}"
DISTRO="${DISTRO:-ampliphy}"
IMAGE="${IMAGE:-phytec-image-slint-demos}"

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

# phyLinux and the `repo` tool it wraps have a `#!/usr/bin/env python` shebang,
# but Ubuntu ships only python3 (no bare `python`), so provide one on PATH.
if ! command -v python >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v python3)" "$HOME/.local/bin/python"
    export PATH="$HOME/.local/bin:$PATH"
fi

slint_demo_ensure_repo_tool

# Fetch the PHYTEC BSP with phyLinux (a repo-manifest wrapper). Drive it
# non-interactively (else it opens SoM/machine menus): MACHINE picks the board,
# -p the SoC platform, -r the pinned release, so builds are reproducible.
wget -q https://download.phytec.de/Software/Linux/Yocto/Tools/phyLinux
chmod +x phyLinux
MACHINE="$MACHINE" ./phyLinux init -p imx8mm -r "$PHYTEC_RELEASE"

# Set up the Yocto build environment. phyLinux lands the sources under sources/;
# source poky's init and pin MACHINE/DISTRO explicitly (oe-init touches unset
# vars / returns non-zero, so relax strict mode across it).
set +eu
source sources/poky/oe-init-build-env build
set -eu

# Drop the Qt6 cluster from PHYTEC's bblayers.conf: a Slint image needs no Qt,
# and meta-qt6/meta-qt6-phytec are the one part fetched from code.qt.io, whose
# repo sync is flaky (a timeout there previously failed the whole build). Once the
# layers are unreferenced a failed fetch of those repos is harmless.
#
# meta-nxp-demo-experience must go with them: it is itself a Qt application (its
# recipe inherits qt6-qmake.bbclass from meta-qt6), so keeping it while removing
# Qt orphans that inherit and breaks parsing. Removing the three together is the
# coherent boundary -- the NXP Qt demo is exactly the bloat we don't want.
#
# We deliberately KEEP the other heavy extras (meta-chromium, meta-imx-ml):
# meta-ampliphy wires chromium into its own dynamic-layer (its chromium recipes
# `require` chromium.inc from meta-chromium, keyed on the fsl-sdk-release
# collection), so removing that layer orphans the require. Kept layers cost only
# parse time -- none is built into the rootfs, because the image installs only
# what our recipe lists (Slint + the GPU userspace), not these packages.
#
# Edit bblayers.conf directly rather than via `bitbake-layers remove-layer`, which
# can't even parse if a layer dir is missing after a partial sync. The pattern is
# anchored on a leading '/' and a trailing space/EOL so it matches each layer's
# own path line and nothing else.
sed -i -E '/\/(meta-qt6|meta-qt6-phytec|meta-nxp-demo-experience)( |$)/d' conf/bblayers.conf
echo "bblayers.conf after pruning unused PHYTEC layers:"
grep -nE '/(sources|layers)/' conf/bblayers.conf || cat conf/bblayers.conf

echo "MACHINE = \"$MACHINE\"" >> conf/local.conf
echo "DISTRO ?= \"$DISTRO\"" >> conf/local.conf

# KMS/DRM demo rendered fullscreen via Slint's linuxkms backend, no compositor.
# opengl is required at build time -- Skia always links GL.
#
# Keep 'wayland' in DISTRO_FEATURES even though we run no compositor: on i.MX the
# Vivante (imx-gpu-viv) userspace is built per graphics backend, selected from
# DISTRO_FEATURES, and only the "wayland" backend ships the GBM/DRM EGL platform
# that linuxkms (eglfs-style) rendering needs -- the same reason Qt's eglfs_kms
# wants it on i.MX. With wayland+x11 both removed you get the legacy "fb" (fbdev)
# backend, which has no GBM/KMS *and* whose prebuilt bins NXP doesn't fully host
# (e.g. libgpuperfcnt-...-fb-...bin 404s). Keeping the feature only selects the
# GBM-capable userspace; it does not pull in a compositor (we never install
# weston). We keep vulkan, and drop only x11 (unused) and opencl (not needed).
cat >> conf/local.conf <<'EOF'
DISTRO_FEATURES:append = " opengl wayland vulkan"
DISTRO_FEATURES:remove = " x11 opencl"
# The Vivante GPU userspace (imx-gpu-viv) ships under NXP's Freescale EULA; accept
# it so it unpacks (the phyLinux flow writes local.conf ourselves, so it has to be
# set here -- NXP's own repo flow does the equivalent with EULA=1).
ACCEPT_FSL_EULA = "1"
EOF

# Add meta-clang, meta-rust-bin and meta-slint. The BSP may already ship
# meta-clang; only add ours if not, to avoid a duplicate layer.
META_CLANG_DIR="$WORK_ROOT/sources/meta-clang"
if ! bitbake-layers show-layers 2>/dev/null | grep -Fq "/meta-clang"; then
    [ -d "$META_CLANG_DIR" ] || git clone -b scarthgap https://github.com/kraj/meta-clang.git "$META_CLANG_DIR"
    bitbake-layers add-layer "$META_CLANG_DIR"
fi
# meta-slint builds its Rust recipes with meta-rust-bin's cargo_bin class, so it
# LAYERDEPENDS on rust-bin-layer -- add meta-rust-bin before meta-slint.
# (meta-rust-bin tracks master; no per-release branches.)
META_RUST_BIN_DIR="$WORK_ROOT/sources/meta-rust-bin"
if ! bitbake-layers show-layers 2>/dev/null | grep -Fq "/meta-rust-bin"; then
    [ -d "$META_RUST_BIN_DIR" ] || git clone https://github.com/rust-embedded/meta-rust-bin.git "$META_RUST_BIN_DIR"
    bitbake-layers add-layer "$META_RUST_BIN_DIR"
fi
slint_demo_add_layer_if_missing "$META_SLINT_DIR"

slint_demo_configure_local_conf conf/local.conf

bitbake "$IMAGE"

# Ship the raw SD-card image, relabelled .wic -> .img (flash to SD, like the Pi
# and TI boards). Match by extension (OE adds a ".rootfs" infix); regular files
# only, so OE's symlink doesn't duplicate it. The PHYTEC machine emits the .wic
# under the per-DISTRO deploy dir; resolve it rather than hardcoding the path.
export ARTIFACT_IMAGE_LABEL=img
DEPLOY="$(find "$WORK_ROOT/build" -maxdepth 4 -type d -path "*/deploy*/images/$MACHINE" | head -n1)"
if [ -z "$DEPLOY" ] || [ ! -d "$DEPLOY" ]; then
    echo "::error::could not locate the image deploy dir for $MACHINE under $WORK_ROOT/build"
    find "$WORK_ROOT/build" -type d -path '*deploy*/images*' 2>/dev/null | head -n 20 || true
    exit 1
fi
echo "Image deploy dir: $DEPLOY"
mapfile -t IMAGES < <(
    find "$DEPLOY" -maxdepth 1 -type f -name '*.wic' | sort
)
slint_demo_collect_artifacts "${IMAGES[@]}"

# README, bundled into the zip alongside the .img.
ARTIFACT_BASENAME="${ARTIFACT_BASENAME:-${MACHINE}-slint-demo}"
TITLE="Slint demo image for the PHYTEC phyBOARD-Polis i.MX 8M Mini"
RULE="${TITLE//?/=}"
cat > "$ARTIFACT_DIR/README.txt" <<EOF
$TITLE
$RULE

This image boots straight into the Slint demo, rendered on the display via
KMS/DRM.

Contents of ${ARTIFACT_BASENAME}.zip:
  ${ARTIFACT_BASENAME}.img   a raw SD-card image (full disk: boot + root partitions)
  README.txt                 this file

Flashing an SD card
-------------------
The image is a plain raw disk image; use any image writer:

  * balenaEtcher / Raspberry Pi Imager: select ${ARTIFACT_BASENAME}.zip (or the
    extracted .img) and pick the SD card.
  * Command line:
      unzip ${ARTIFACT_BASENAME}.zip
      sudo dd if=${ARTIFACT_BASENAME}.img of=/dev/sdX bs=4M conv=fsync status=progress
    (replace /dev/sdX with your SD card device)

First boot
----------
Set the board's boot switches to SD-card boot, insert the card, connect a
display, and power on. The Slint demo starts automatically on the screen.

Networking
----------
  * Wired Ethernet comes up automatically via DHCP.
  * Zeroconf/mDNS is enabled, so the board is reachable at <hostname>.local.
  * An SSH server (OpenSSH) is running on port 22 (set a root password or key
    to log in).
EOF
echo "Wrote README.txt"
