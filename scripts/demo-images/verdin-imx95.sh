#!/bin/bash
# Build the Slint demo image for the Toradex Verdin iMX95 SoM. Toradex ships its
# BSP as a `repo` manifest; we pin a stable BSP release tag. The image boots
# straight into the Slint launcher on KMS/DRM via the linuxkms backend -- no
# Wayland/X11 compositor. The i.MX95 has an Arm Mali GPU (userspace via
# mali-imx-*; see the image recipe).
#
# Env overrides: TDX_MANIFEST_TAG, MACHINE, DISTRO, IMAGE, WORK_ROOT,
# ARTIFACT_DIR, SSTATE_DIR.
set -euo pipefail

TDX_MANIFEST_TAG="${TDX_MANIFEST_TAG:-7.7.0}"
MACHINE="${MACHINE:-verdin-imx95}"
DISTRO="${DISTRO:-tdx-xwayland}"
IMAGE="${IMAGE:-tdx-image-slint-demos}"

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

# Fetch the Toradex BSP via repo. Use https (not git://) so it works through the
# CI HTTPS proxy. Pin the BSP release tag for reproducibility.
repo init -u https://git.toradex.com/toradex-manifest.git \
    -b "refs/tags/$TDX_MANIFEST_TAG" -m tdxref/default.xml --no-clone-bundle
repo sync -j"$(nproc)" --no-clone-bundle

# Toradex's `. export` creates build/, sources the OE environment and leaves us
# in build/. It touches unset vars / returns non-zero, so relax strict mode.
set +eu
source ./export
set -eu

# Pin MACHINE (hard =, overriding the template's default) and DISTRO. We keep the
# tdx-xwayland distro but never install a compositor -- the image is a single
# fullscreen KMS app.
echo "MACHINE = \"$MACHINE\"" >> conf/local.conf
echo "DISTRO ?= \"$DISTRO\"" >> conf/local.conf

cat >> conf/local.conf <<'EOF'

# NXP i.MX GPU/VPU firmware is under the Freescale EULA; accept it non-interactively.
ACCEPT_FSL_EULA = "1"

# KMS/DRM demo rendered fullscreen via Slint's linuxkms backend, no compositor.
# opengl is required at build time -- Skia always links GL. We drop the
# compositor features (wayland/x11) -- the i.MX95 Mali userspace ships a single
# GBM-capable EGL (no Vivante-style backend split), so that costs us no KMS/GBM
# -- but keep vulkan: the Mali driver (mali-imx, which PROVIDES virtual/libgbm)
# DEPENDS on vulkan-loader, which requires the vulkan DISTRO_FEATURE. Without it
# the whole libgbm -> launcher chain is unbuildable.
DISTRO_FEATURES:append = " opengl"
DISTRO_FEATURES:remove = " wayland x11 opencl"
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

# --- Package the Toradex Easy Installer (TEZI) output ---
# teziimg deploys the Easy Installer bundle -- image.json plus its payload files
# (rootfs, bootloader, boilerplate). We ship it as a single zip: extract it onto a
# USB stick and Easy Installer detects the image and offers it for install. One
# asset, like the other boards (the bundle's own files have generic vendor names,
# so publishing them individually would clutter the shared release).
ARTIFACT_BASENAME="${ARTIFACT_BASENAME:-${MACHINE}-slint-demo}"

# Resolve the deploy dir from bitbake (Toradex uses deploy/images, not tmp/deploy).
DEPLOY="$(bitbake -e "$IMAGE" 2>/dev/null | sed -n 's/^DEPLOY_DIR_IMAGE="\(.*\)"$/\1/p' | tail -n1)"
if [ -z "$DEPLOY" ] || [ ! -d "$DEPLOY" ]; then
    DEPLOY="$(find "$WORK_ROOT" -type d -path "*/deploy/images/$MACHINE" 2>/dev/null | head -n1)"
fi
[ -n "$DEPLOY" ] && [ -d "$DEPLOY" ] || { echo "::error::deploy dir for $MACHINE not found"; exit 1; }

# Locate the bundle. teziimg emits it either as a directory holding image.json or
# (as on BSP 7.x) as a Tezi tarball -- handle both.
TEZI_DIR=""
TEZI_JSON="$(find "$DEPLOY" -maxdepth 3 -name image.json -printf '%T@\t%p\n' 2>/dev/null | sort -nr | head -n1 | cut -f2)"
if [ -n "$TEZI_JSON" ] && [ -f "$TEZI_JSON" ]; then
    TEZI_DIR="$(dirname "$TEZI_JSON")"
else
    TEZI_TAR="$(find "$DEPLOY" -maxdepth 1 -type f \( -name '*Tezi*.tar' -o -name '*Tezi*.tar.*' -o -name '*teziimg*.tar' -o -name '*teziimg*.tar.*' \) -printf '%T@\t%p\n' 2>/dev/null | sort -nr | head -n1 | cut -f2)"
    if [ -n "$TEZI_TAR" ] && [ -f "$TEZI_TAR" ]; then
        echo "Easy Installer bundle tarball: $TEZI_TAR"
        TEZI_DIR="$WORK_ROOT/tezi-bundle"
        rm -rf "$TEZI_DIR"; mkdir -p "$TEZI_DIR"
        tar -xaf "$TEZI_TAR" -C "$TEZI_DIR"
        # The tarball usually contains a single top-level folder; if so, use it as
        # the bundle root so image.json sits at the top.
        if [ ! -f "$TEZI_DIR/image.json" ]; then
            INNER="$(find "$TEZI_DIR" -mindepth 2 -maxdepth 2 -name image.json | head -n1)"
            [ -n "$INNER" ] && TEZI_DIR="$(dirname "$INNER")"
        fi
    fi
fi
if [ -z "$TEZI_DIR" ] || [ ! -f "$TEZI_DIR/image.json" ]; then
    echo "::error::could not locate the Easy Installer bundle (no image.json, no Tezi tarball) under $DEPLOY"
    echo "--- deploy dir contents ---"
    find "$DEPLOY" -maxdepth 2 -printf '%y %10s %p\n' 2>/dev/null || true
    exit 1
fi
echo "Easy Installer bundle: $TEZI_DIR"
ls -l "$TEZI_DIR"

mkdir -p "$ARTIFACT_DIR"

# README, bundled inside the zip alongside the Easy Installer files (so the
# release carries a single self-describing asset).
TITLE="Slint demo image for the Toradex Verdin iMX95"
RULE="${TITLE//?/=}"
cat > "$TEZI_DIR/README.txt" <<EOF
$TITLE
$RULE

A Toradex Easy Installer image that boots straight into the Slint demo, rendered
on the display via KMS/DRM.

Installing
----------
  1. Extract ${ARTIFACT_BASENAME}-easy-installer.zip onto a FAT/exFAT USB stick
     (the extracted folder must contain image.json).
  2. Put the module into recovery mode and start the Toradex Easy Installer (see
     the Toradex docs for your carrier board's recovery procedure).
  3. Insert the USB stick; Easy Installer detects the image -- select it to
     install to the on-module eMMC.

First boot
----------
Connect a display and power on. The Slint demo starts automatically.

Networking
----------
  * Wired Ethernet comes up automatically via DHCP.
  * Zeroconf/mDNS is enabled, so the board is reachable at <hostname>.local.
  * An SSH server (OpenSSH) is running on port 22 (set a root password or key
    to log in).
EOF

# A single zip of the whole bundle. -0 (store): the payloads are already
# compressed.
( cd "$TEZI_DIR" && zip -r -0 -q "$ARTIFACT_DIR/${ARTIFACT_BASENAME}-easy-installer.zip" . )
echo "Wrote ${ARTIFACT_BASENAME}-easy-installer.zip"
ls -l "$ARTIFACT_DIR"
