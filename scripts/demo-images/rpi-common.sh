#!/bin/bash
# Shared build for the Raspberry Pi Slint demo images. The rpi4.sh / rpi5.sh
# wrappers set MACHINE, then call slint_demo_build_rpi; the rest is common.
# meta-raspberrypi is a community layer, so we clone poky + the layers directly.
#
# Env: MACHINE, META_SLINT_DIR (required); YOCTO_RELEASE (scarthgap), DISTRO
# (poky), IMAGE, WORK_ROOT, ARTIFACT_DIR, SSTATE_DIR (optional).

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

    # oe-init-build-env touches unset vars / returns non-zero, so relax strict mode.
    set +eu
    source "$src/poky/oe-init-build-env" "$work_root/build"
    set -eu

    # Layer order matters for LAYERDEPENDS (meta-python before meta-networking,
    # meta-rust-bin before meta-slint).
    bitbake-layers add-layer \
        "$src/meta-openembedded/meta-oe" \
        "$src/meta-openembedded/meta-python" \
        "$src/meta-openembedded/meta-multimedia" \
        "$src/meta-openembedded/meta-networking" \
        "$src/meta-raspberrypi" \
        "$src/meta-clang" \
        "$src/meta-rust-bin" \
        "$meta_slint_dir"

    echo "MACHINE = \"$machine\"" >> conf/local.conf
    echo "DISTRO ?= \"$distro\"" >> conf/local.conf
    # KMS/DRM + GLES (Mesa V3D).
    echo 'DISTRO_FEATURES:append = " opengl"' >> conf/local.conf
    # Accept the RPi WiFi firmware's license flag so it builds instead of skipping.
    echo 'LICENSE_FLAGS_ACCEPTED:append = " synaptics-killswitch"' >> conf/local.conf
    # slint-demos autostart is a systemd unit and DHCP uses systemd-networkd.
    echo 'INIT_MANAGER = "systemd"' >> conf/local.conf
    slint_demo_configure_local_conf conf/local.conf

    bitbake "$image"

    # Ship the raw image, relabelled .wic -> .img. Match by extension (OE adds a
    # ".rootfs" infix); regular files only, so OE's symlink doesn't duplicate it.
    export ARTIFACT_IMAGE_LABEL=img
    local deploy="tmp/deploy/images/$machine"
    local -a slint_demo_images
    mapfile -t slint_demo_images < <(
        find "$deploy" -maxdepth 1 -type f -name '*.wic' | sort
    )
    slint_demo_collect_artifacts "${slint_demo_images[@]}"

    # README, bundled into the zip alongside the .img.
    local artifact_basename="${ARTIFACT_BASENAME:-${machine}-slint-demo}"
    local board_desc
    case "$machine" in
        raspberrypi4*) board_desc="Raspberry Pi 4" ;;
        raspberrypi5)  board_desc="Raspberry Pi 5" ;;
        *)             board_desc="Raspberry Pi ($machine)" ;;
    esac
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

  * Raspberry Pi Imager: "Use custom" -> select ${artifact_basename}.zip -> pick
    the SD card.
  * Command line:
      unzip ${artifact_basename}.zip
      sudo dd if=${artifact_basename}.img of=/dev/sdX bs=4M conv=fsync status=progress
    (replace /dev/sdX with your SD card device)

First boot
----------
Insert the card, connect an HDMI display, and power on. The Slint demo starts
automatically on the screen.

Networking
----------
  * Wired Ethernet comes up automatically via DHCP.
  * Zeroconf/mDNS is enabled, so the board is reachable by name at
    <hostname>.local -- the default hostname is the machine name, e.g.
    ${machine}.local.
  * An SSH server (dropbear) is running on port 22 (set a root password or key
    to log in).

Wi-Fi is not preconfigured.
EOF
    echo "Wrote README.txt"
}
