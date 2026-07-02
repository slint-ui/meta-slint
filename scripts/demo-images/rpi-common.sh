#!/bin/bash
# Shared build steps for the Raspberry Pi Slint demo images.
#
# The per-Pi scripts (rpi4.sh, rpi5.sh) differ only in the target MACHINE;
# everything else -- the poky/meta-* checkout, the layer set, the distro
# features and the artifact collection -- is identical, so it lives here.
# Source common.sh and this file, set MACHINE, then call slint_demo_build_rpi.
#
# meta-raspberrypi is a plain community layer, so we bootstrap by cloning poky
# and the extra layers directly (no vendor manifest or EULA involved).
#
# Reads from the environment (defaults in parentheses):
#   YOCTO_RELEASE  (scarthgap)   branch used for poky + the OE layers
#   MACHINE        (required)    set by the caller, e.g. raspberrypi5
#   DISTRO         (poky)
#   IMAGE          (rpi-image-slint-demos)
#   WORK_ROOT      ($PWD)        build tree is created here
#   ARTIFACT_DIR   ($WORK_ROOT/artifacts)  flashable image copied here
#   SSTATE_DIR     (unset)       set to a persistent path to reuse an sstate cache
#   META_SLINT_DIR (required)    path to this meta-slint checkout

slint_demo_build_rpi() {
    local yocto_release="${YOCTO_RELEASE:-scarthgap}"
    local machine="${MACHINE:?MACHINE must be set by the caller (e.g. raspberrypi5)}"
    local distro="${DISTRO:-poky}"
    local image="${IMAGE:-rpi-image-slint-demos}"
    local meta_slint_dir="${META_SLINT_DIR:?META_SLINT_DIR must be set by the caller}"

    local work_root="${WORK_ROOT:-$PWD}"
    export ARTIFACT_DIR="${ARTIFACT_DIR:-$work_root/artifacts}"
    mkdir -p "$work_root"
    cd "$work_root"

    slint_demo_ensure_git_identity

    # --- Fetch poky and the layers (all community git, no manifest/EULA). ---
    local src="$work_root/sources"
    mkdir -p "$src"
    _rpi_clone() {  # _rpi_clone <dir-name> <url> <branch>
        local dir="$src/$1"
        if [ ! -d "$dir" ]; then
            git clone -b "$3" --single-branch "$2" "$dir"
        fi
    }
    _rpi_clone poky              https://git.yoctoproject.org/poky              "$yocto_release"
    _rpi_clone meta-openembedded https://git.openembedded.org/meta-openembedded "$yocto_release"
    _rpi_clone meta-raspberrypi  https://git.yoctoproject.org/meta-raspberrypi  "$yocto_release"
    _rpi_clone meta-clang        https://github.com/kraj/meta-clang.git         "$yocto_release"
    # meta-rust-bin tracks master (no per-release branches).
    if [ ! -d "$src/meta-rust-bin" ]; then
        git clone https://github.com/rust-embedded/meta-rust-bin.git "$src/meta-rust-bin"
    fi

    # --- Initialise the build directory. ---
    # oe-init-build-env references unset variables (BBSERVER, ...) and returns
    # non-zero in places, so relax the shell's strict flags while sourcing it.
    set +eu
    source "$src/poky/oe-init-build-env" "$work_root/build"
    set -eu

    # --- Add the layers. Order matters for LAYERDEPENDS: meta-python before
    # meta-networking, and meta-rust-bin before meta-slint. meta-raspberrypi
    # depends on the meta-oe/python/multimedia/networking layers. ---
    bitbake-layers add-layer \
        "$src/meta-openembedded/meta-oe" \
        "$src/meta-openembedded/meta-python" \
        "$src/meta-openembedded/meta-multimedia" \
        "$src/meta-openembedded/meta-networking" \
        "$src/meta-raspberrypi" \
        "$src/meta-clang" \
        "$src/meta-rust-bin" \
        "$meta_slint_dir"

    # --- Machine + Slint + disk-conservation configuration. ---
    echo "MACHINE = \"$machine\"" >> conf/local.conf
    echo "DISTRO ?= \"$distro\"" >> conf/local.conf
    # The Slint demos need an OpenGL-capable distro (KMS/DRM + GLES via Mesa's V3D).
    echo 'DISTRO_FEATURES:append = " opengl"' >> conf/local.conf
    # The Raspberry Pi WiFi firmware (linux-firmware-rpidistro), pulled in by the
    # base image, carries the "synaptics-killswitch" license flag; accept it so the
    # firmware is buildable instead of skipped.
    echo 'LICENSE_FLAGS_ACCEPTED:append = " synaptics-killswitch"' >> conf/local.conf
    slint_demo_configure_local_conf conf/local.conf

    # Point sstate at a persistent cache (e.g. a mounted Hetzner Volume) when the
    # workflow provides one; DL_DIR is deliberately left at its default so downloads
    # stay ephemeral. A warm sstate restores most recipes without re-fetching.
    if [ -n "${SSTATE_DIR:-}" ]; then
        echo "SSTATE_DIR = \"$SSTATE_DIR\"" >> conf/local.conf
    fi

    # --- Build. ---
    bitbake "$image"

    # --- Collect the flashable image for the workflow to publish. ---
    # Ship the compressed image plus its block map; bmaptool can flash the
    # .wic.zst directly using the .bmap. Match by extension (OpenEmbedded adds a
    # ".rootfs" infix), and restrict to regular files so OE's convenience
    # symlinks don't duplicate the (large) image in the artifact.
    local deploy="tmp/deploy/images/$machine"
    local -a slint_demo_images
    mapfile -t slint_demo_images < <(
        find "$deploy" -maxdepth 1 -type f \( -name '*.wic.zst' -o -name '*.wic.bmap' \) | sort
    )
    slint_demo_collect_artifacts "${slint_demo_images[@]}"
}
