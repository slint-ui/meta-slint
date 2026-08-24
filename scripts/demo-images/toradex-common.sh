#!/bin/bash
# Shared build for the Toradex Slint demo images. A per-board wrapper (e.g.
# verdin-imx8mp.sh) sets MACHINE, BOARD_DESC and TDX_GPU, then calls
# slint_demo_build_toradex; the rest is common.
#
# Toradex ships its BSP as a `repo` manifest; we pin a stable BSP release tag.
# The image boots straight into the Slint launcher on KMS/DRM via the linuxkms
# backend -- no Wayland/X11 compositor -- and ships as a Toradex Easy Installer
# (TEZI) bundle.
#
# TDX_GPU selects the board's GPU stack, which is the only board-specific part:
#   mali    - i.MX95 (Arm Mali, mali-imx). Single GBM-capable EGL, so the wayland
#             DISTRO_FEATURE is not needed and we drop it.
#   vivante - i.MX8 (Vivante, imx-gpu-viv). MUST keep the wayland DISTRO_FEATURE:
#             the recipe picks its backend with
#               BACKEND = contains(DISTRO_FEATURES, "wayland", "wayland", "fb")
#             and only the wayland build ships the GBM/DRM EGL that linuxkms
#             needs (the fb build is legacy fbdev). Keeping the feature selects
#             the right userspace; it does not pull in a compositor, and we never
#             install weston.
# The matching EGL/GLES packages are installed by the image recipe, keyed on the
# imxmali / imxviv machine overrides.
#
# Env: MACHINE, BOARD_DESC, TDX_GPU (required); TDX_MANIFEST_TAG, DISTRO, IMAGE,
# META_SLINT_DIR, WORK_ROOT, ARTIFACT_DIR, SSTATE_DIR (optional).

slint_demo_build_toradex() {
    local machine="${MACHINE:?set by the caller, e.g. verdin-imx8mp}"
    local board_desc="${BOARD_DESC:-Toradex $machine}"
    local gpu="${TDX_GPU:?set by the caller: mali or vivante}"
    local manifest_tag="${TDX_MANIFEST_TAG:-7.7.0}"
    local distro="${DISTRO:-tdx-xwayland}"
    local image="${IMAGE:-tdx-image-slint-demos}"
    local meta_slint_dir="${META_SLINT_DIR:?set by the caller}"

    local WORK_ROOT="${WORK_ROOT:-$PWD}"
    local ARTIFACT_DIR="${ARTIFACT_DIR:-$WORK_ROOT/artifacts}"
    export ARTIFACT_DIR
    mkdir -p "$WORK_ROOT"
    cd "$WORK_ROOT"

    slint_demo_ensure_git_identity
    slint_demo_ensure_repo_tool

    # Fetch the Toradex BSP via repo. Use https (not git://) so it works through
    # the CI HTTPS proxy. Pin the BSP release tag for reproducibility.
    repo init -u https://git.toradex.com/toradex-manifest.git \
        -b "refs/tags/$manifest_tag" -m tdxref/default.xml --no-clone-bundle
    repo sync -j"$(nproc)" --no-clone-bundle

    # Toradex's `. export` creates build/, sources the OE environment and leaves
    # us in build/. It touches unset vars / returns non-zero, so relax strict mode.
    set +eu
    source ./export
    set -eu

    # Pin MACHINE (hard =, overriding the template's default) and DISTRO. We keep
    # the tdx-xwayland distro but never install a compositor -- the image is a
    # single fullscreen KMS app.
    echo "MACHINE = \"$machine\"" >> conf/local.conf
    echo "DISTRO ?= \"$distro\"" >> conf/local.conf

    cat >> conf/local.conf <<'EOF'

# NXP i.MX GPU/VPU firmware is under the Freescale EULA; accept it non-interactively.
ACCEPT_FSL_EULA = "1"

# KMS/DRM demo rendered fullscreen via Slint's linuxkms backend, no compositor.
# opengl is required at build time -- Skia always links GL. x11 and opencl are
# unused. vulkan stays: on i.MX95 the Mali driver (which PROVIDES virtual/libgbm)
# DEPENDS on vulkan-loader, so dropping the feature makes the libgbm -> launcher
# chain unbuildable.
DISTRO_FEATURES:append = " opengl"
DISTRO_FEATURES:remove = " x11 opencl"
EOF

    # wayland: see the TDX_GPU note at the top -- Vivante needs it to get the
    # GBM-capable EGL build, Mali does not.
    if [ "$gpu" = "vivante" ]; then
        echo 'DISTRO_FEATURES:append = " wayland"' >> conf/local.conf
    else
        echo 'DISTRO_FEATURES:remove = " wayland"' >> conf/local.conf
    fi

    # Add meta-clang, meta-rust-bin and meta-slint. The BSP may already ship
    # meta-clang; only add ours if not, to avoid a duplicate layer.
    local meta_clang_dir="$WORK_ROOT/sources/meta-clang"
    if ! bitbake-layers show-layers 2>/dev/null | grep -Fq "/meta-clang"; then
        [ -d "$meta_clang_dir" ] || git clone -b scarthgap https://github.com/kraj/meta-clang.git "$meta_clang_dir"
        bitbake-layers add-layer "$meta_clang_dir"
    fi
    # meta-slint builds its Rust recipes with meta-rust-bin's cargo_bin class, so
    # it LAYERDEPENDS on rust-bin-layer -- add meta-rust-bin before meta-slint.
    # (meta-rust-bin tracks master; no per-release branches.)
    local meta_rust_bin_dir="$WORK_ROOT/sources/meta-rust-bin"
    if ! bitbake-layers show-layers 2>/dev/null | grep -Fq "/meta-rust-bin"; then
        [ -d "$meta_rust_bin_dir" ] || git clone https://github.com/rust-embedded/meta-rust-bin.git "$meta_rust_bin_dir"
        bitbake-layers add-layer "$meta_rust_bin_dir"
    fi
    slint_demo_add_layer_if_missing "$meta_slint_dir"

    slint_demo_configure_local_conf conf/local.conf

    bitbake "$image"

    # --- Package the Toradex Easy Installer (TEZI) output ---
    # teziimg deploys the Easy Installer bundle -- image.json plus its payload files
    # (rootfs, bootloader, boilerplate). We ship it as a single zip: extract it onto a
    # USB stick and Easy Installer detects the image and offers it for install. One
    # asset, like the other boards (the bundle's own files have generic vendor names,
    # so publishing them individually would clutter the shared release).
    ARTIFACT_BASENAME="${ARTIFACT_BASENAME:-${MACHINE}-slint-demo}"

    # Resolve the deploy dir from bitbake (Toradex uses deploy/images, not tmp/deploy).
    DEPLOY="$(bitbake -e "$image" 2>/dev/null | sed -n 's/^DEPLOY_DIR_IMAGE="\(.*\)"$/\1/p' | tail -n1)"
    if [ -z "$DEPLOY" ] || [ ! -d "$DEPLOY" ]; then
        DEPLOY="$(find "$WORK_ROOT" -type d -path "*/deploy/images/$machine" 2>/dev/null | head -n1)"
    fi
    [ -n "$DEPLOY" ] && [ -d "$DEPLOY" ] || { echo "::error::deploy dir for $machine not found"; exit 1; }

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
    TITLE="Slint demo image for the $board_desc"
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
}
