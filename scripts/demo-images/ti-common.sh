#!/bin/bash
# Shared build for the TI Sitara Slint demo images (currently AM62Px). The
# am62px.sh wrapper sets MACHINE and the board description, then calls
# slint_demo_build_ti; the rest is common.
#
# The TI Processor SDK ships as an Arago oe-layersetup config (like ST's/NXP's
# repo manifests): oe-layertool-setup.sh clones poky + meta-arm + meta-ti + the
# OE layers at TI's pinned, tested revisions and writes bblayers.conf. We add
# meta-clang + meta-slint on top. The default config is SDK 12, which is on the
# wrynose OE series (matches meta-slint on the dev branch).
#
# Env: MACHINE, BOARD_DESC, META_SLINT_DIR (required); TI_OECONFIG,
# OE_LAYERSETUP_URL, META_CLANG_BRANCH, IMAGE, WORK_ROOT, ARTIFACT_DIR,
# SSTATE_DIR (optional).

slint_demo_build_ti() {
    local machine="${MACHINE:?set by the caller, e.g. am62pxx-evm}"
    local board_desc="${BOARD_DESC:-TI $machine}"
    local image="${IMAGE:-ti-image-slint-demos}"
    local meta_slint_dir="${META_SLINT_DIR:?set by the caller}"
    local oe_layersetup_url="${OE_LAYERSETUP_URL:-https://git.ti.com/git/arago-project/oe-layersetup.git}"
    local ti_oeconfig="${TI_OECONFIG:-configs/processor-sdk/processor-sdk-master-12.00.00.07.04-config.txt}"
    # meta-clang tracks the same OE as the SDK; SDK 12 is on OE master.
    local meta_clang_branch="${META_CLANG_BRANCH:-master}"

    local work_root="${WORK_ROOT:-$PWD}"
    export ARTIFACT_DIR="${ARTIFACT_DIR:-$work_root/artifacts}"
    mkdir -p "$work_root"
    cd "$work_root"

    slint_demo_ensure_git_identity

    # Host packages the TI Processor SDK build expects (Yocto build docs).
    sudo apt-get update
    sudo apt-get install -y \
        build-essential chrpath cpio diffstat file gawk git-lfs lz4 pigz \
        python3 python3-git python3-jinja2 python3-pexpect socat texinfo \
        u-boot-tools unzip wget xz-utils zstd || true

    # Fetch the BSP via TI's oe-layersetup (pinned Processor SDK revisions). It
    # clones the layers under <setup>/sources and writes <setup>/build.
    local setup="$work_root/oe-layersetup"
    [ -d "$setup/.git" ] || git clone "$oe_layersetup_url" "$setup"
    ( cd "$setup" && ./oe-layertool-setup.sh -f "$ti_oeconfig" )

    # conf/setenv sources oe-init-build-env; run it in this shell (relaxing strict
    # flags, as it touches unset vars) so bitbake lands on PATH.
    local build="$setup/build"
    set +eu
    cd "$build"
    . conf/setenv
    set -eu
    if ! command -v bitbake-layers >/dev/null 2>&1; then
        echo "::error::TI oe-layersetup did not set up the build environment (bitbake not on PATH)"; exit 1
    fi

    # Add meta-clang and meta-slint on top of the TI layers. meta-slint on this
    # (wrynose) branch builds Rust via oe-core's cargo, so no meta-rust-bin.
    local layers="$setup/sources"
    local meta_clang_dir="$layers/meta-clang"
    if ! bitbake-layers show-layers 2>/dev/null | grep -Fq "/meta-clang"; then
        [ -d "$meta_clang_dir" ] || git clone -b "$meta_clang_branch" https://github.com/kraj/meta-clang.git "$meta_clang_dir"
        bitbake-layers add-layer "$meta_clang_dir"
    fi
    slint_demo_add_layer_if_missing "$meta_slint_dir"

    echo "MACHINE = \"$machine\"" >> conf/local.conf
    cat >> conf/local.conf <<'EOF'

# Framebuffer/KMS demo, no compositor. opengl is required at build time even for
# GPU-less boards: Slint's Skia renderer always links GL, so GLES/EGL must be
# present to build (it just isn't used at runtime when rendering in software).
DISTRO_FEATURES:append = " opengl"
DISTRO_FEATURES:remove = " wayland x11 vulkan opencl"
EOF
    # GPU boards (AM62Px) render with the GPU via TI's proprietary Imagination
    # DDK; accept its license so the GLES userspace is built in. GPU-less boards
    # (AM62L) leave it out and let Skia raster in software (TI_GPU=0, set by the
    # wrapper; the recipes select the software backend for that machine).
    if [ "${TI_GPU:-1}" = "1" ]; then
        echo 'LICENSE_FLAGS_ACCEPTED:append = " ti-img-rogue"' >> conf/local.conf
    fi
    echo 'INIT_MANAGER = "systemd"' >> conf/local.conf
    slint_demo_configure_local_conf conf/local.conf

    bitbake "$image"

    # Ship the raw .wic, relabelled .wic -> .img (flash to SD, like the Pi). Match
    # by extension (OE adds a ".rootfs" infix); regular files only, so OE's symlink
    # doesn't duplicate it.
    export ARTIFACT_IMAGE_LABEL=img
    # Resolve the image deploy dir from bitbake -- the TI/Arago config uses a
    # non-default TMPDIR (arago-tmp/, not tmp/), so don't hardcode the path. Fall
    # back to a tree search, then fail loudly rather than run `find ''`.
    local deploy
    deploy="$(bitbake -e "$image" 2>/dev/null | sed -n 's/^DEPLOY_DIR_IMAGE="\(.*\)"$/\1/p' | tail -n1)"
    if [ -z "$deploy" ] || [ ! -d "$deploy" ]; then
        deploy="$(find "$build" -type d -path "*/deploy/images/$machine" 2>/dev/null | head -n1)"
    fi
    if [ -z "$deploy" ] || [ ! -d "$deploy" ]; then
        echo "::error::could not locate the image deploy dir for $machine under $build"
        find "$build" -type d -path '*deploy/images*' 2>/dev/null | head -n 20 || true
        return 1
    fi
    echo "Image deploy dir: $deploy"
    local -a slint_demo_images
    mapfile -t slint_demo_images < <(
        find "$deploy" -maxdepth 1 -type f -name '*.wic' | sort
    )
    slint_demo_collect_artifacts "${slint_demo_images[@]}"

    # README, bundled into the zip alongside the .img.
    local artifact_basename="${ARTIFACT_BASENAME:-${machine}-slint-demo}"
    local title="Slint demo image for the $board_desc"
    local rule="${title//?/=}"
    cat > "$ARTIFACT_DIR/README.txt" <<EOF
$title
$rule

This image boots straight into the Slint demo, rendered on the HDMI display
via KMS/DRM.

Contents of ${artifact_basename}.zip:
  ${artifact_basename}.img   a raw SD-card image (full disk: boot + root partitions)
  README.txt                 this file

Flashing an SD card
-------------------
The image is a plain raw disk image; use any image writer:

  * balenaEtcher / Raspberry Pi Imager: select ${artifact_basename}.zip (or the
    extracted .img) and pick the SD card.
  * Command line:
      unzip ${artifact_basename}.zip
      sudo dd if=${artifact_basename}.img of=/dev/sdX bs=4M conv=fsync status=progress
    (replace /dev/sdX with your SD card device)

First boot
----------
Set the board's boot switches to SD-card boot, insert the card, connect an HDMI
display, and power on. The Slint demo starts automatically on the screen.

Networking
----------
  * Wired Ethernet comes up automatically via DHCP.
  * Zeroconf/mDNS is enabled, so the board is reachable at <hostname>.local
    (default hostname is the machine name, e.g. ${machine}.local).
  * An SSH server (dropbear) is running on port 22 (set a root password or key
    to log in).
EOF
    echo "Wrote README.txt"
}
