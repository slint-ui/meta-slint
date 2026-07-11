#!/bin/bash
# Shared build for the STMicroelectronics OpenSTLinux Slint demo images. The
# stm32mp1.sh / stm32mp2.sh wrappers set MACHINE, the README example BOARD and
# its BOOT_NOTE, then call slint_demo_build_stm32; the rest is common.
#
# Env: MACHINE, BOARD, META_SLINT_DIR (required); BOOT_NOTE, OSTL_MANIFEST_TAG,
# OSTL_MANIFEST_FILE, DISTRO, IMAGE, WORK_ROOT, ARTIFACT_DIR, SSTATE_DIR (optional).

slint_demo_build_stm32() {
    local machine="${MACHINE:?set by the caller, e.g. stm32mp1}"
    local board="${BOARD:?set by the caller (README example board)}"
    local manifest_tag="${OSTL_MANIFEST_TAG:-openstlinux-6.6-yocto-scarthgap-mpu-v26.06.10}"
    local manifest_file="${OSTL_MANIFEST_FILE:-default.xml}"
    local distro="${DISTRO:-openstlinux-weston}"
    local image="${IMAGE:-st-image-slint-demos}"
    local meta_slint_dir="${META_SLINT_DIR:?set by the caller}"
    # Apostrophe-free: an apostrophe inside a "${VAR:-default}" word still parses as a quote.
    local default_boot_note='Put your board into USB serial-boot (flashing) mode and connect it to
   the host. See the ST "Populate the target" guide for the exact boot-switch
   settings for your board:
     https://wiki.st.com/stm32mpu/wiki/Category:Let%27s_start'
    local boot_note="${BOOT_NOTE:-$default_boot_note}"

    local work_root="${WORK_ROOT:-$PWD}"
    export ARTIFACT_DIR="${ARTIFACT_DIR:-$work_root/artifacts}"
    mkdir -p "$work_root"
    cd "$work_root"

    slint_demo_ensure_git_identity
    slint_demo_ensure_repo_tool

    # Fetch the OpenSTLinux BSP via repo.
    repo init -u https://github.com/STMicroelectronics/oe-manifest.git \
        -b "refs/tags/$manifest_tag" -m "$manifest_file" --no-clone-bundle
    repo sync -j"$(nproc)" --no-clone-bundle

    # envsetup.sh prompts interactively on unsupported hosts and, with no stdin in
    # CI, defaults to "no" and aborts. Pre-install the packages it wants and feed it
    # a bounded number of "y"s. It must be sourced in this shell (brace group keeps
    # the stdin redirect out of a subshell), and touches unset vars, so relax
    # strict mode while it runs.
    sudo apt-get update
    sudo apt-get install -y \
        bsdmainutils gcc-multilib git-lfs libgmp-dev libmpc-dev libssl-dev \
        pylint python3-git python3-pip socat texinfo xterm || true
    sudo apt-get install -y libsdl1.2-dev 2>/dev/null || true

    set +eu
    { DISTRO="$distro" MACHINE="$machine" source layers/meta-st/scripts/envsetup.sh; } < <(yes | head -n 20)
    set -eu
    if ! command -v bitbake-layers >/dev/null 2>&1; then
        echo "::error::ST envsetup did not set up the build environment (bitbake not on PATH)"; exit 1
    fi

    # Add meta-clang, meta-rust-bin and meta-slint. The BSP may already ship
    # meta-clang/meta-rust-bin; only add ours if not, to avoid a duplicate layer.
    local meta_clang_dir="$work_root/layers/meta-clang"
    if ! bitbake-layers show-layers 2>/dev/null | grep -Fq "/meta-clang"; then
        [ -d "$meta_clang_dir" ] || git clone -b scarthgap https://github.com/kraj/meta-clang.git "$meta_clang_dir"
        bitbake-layers add-layer "$meta_clang_dir"
    fi
    local meta_rust_bin_dir="$work_root/layers/meta-rust-bin"
    if ! bitbake-layers show-layers 2>/dev/null | grep -Fq "/meta-rust-bin"; then
        [ -d "$meta_rust_bin_dir" ] || git clone https://github.com/rust-embedded/meta-rust-bin.git "$meta_rust_bin_dir"
        bitbake-layers add-layer "$meta_rust_bin_dir"
    fi
    slint_demo_add_layer_if_missing "$meta_slint_dir"

    slint_demo_configure_local_conf conf/local.conf
    cat >> conf/local.conf <<'EOF'

# LinuxKMS framebuffer backend: no wayland/x11 (image sets CONFLICT_DISTRO_FEATURES).
DISTRO_FEATURES:append = " opengl"
DISTRO_FEATURES:remove = " wayland x11 vulkan opencl"
EOF

    bitbake "$image"

    # STM32MP boards flash with STM32CubeProgrammer from a FlashLayout .tsv that
    # references the partition binaries by relative path, so ship the whole deploy
    # images dir as a tarball. Avoid `ls` to find it: its non-zero exit on a missing
    # candidate would trip set -e before the -d check.
    local deploy=""
    local _d
    for _d in "tmp-glibc/deploy/images/$machine" \
              "tmp/deploy/images/$machine" \
              "$work_root"/build-*/tmp-glibc/deploy/images/"$machine"; do
        if [ -d "$_d" ]; then deploy="$_d"; break; fi
    done
    if [ -z "$deploy" ]; then
        echo "::error::deploy images dir not found for $machine" >&2
        find "$work_root" -maxdepth 6 -type d -name "$machine" -path '*deploy/images*' 2>/dev/null | head
        exit 1
    fi
    echo "Deploy dir: $deploy"
    echo "--- deploy contents ---"; ls -la "$deploy"
    echo "--- FlashLayout .tsv files ---"; find "$deploy" -path '*flashlayout*' -name '*.tsv' | sort
    echo "--- deploy size ---"; du -sh "$deploy" 2>/dev/null || true

    # Drop the NAND (UBI/UBIFS) images and their FlashLayouts: the MP15 boards can
    # boot from NAND, so OpenSTLinux emits ~0.8 GB of extra rootfs copies nobody
    # flashing over SD/eMMC/NOR needs. No-op on machines without NAND (stm32mp2).
    echo "--- pruning NAND (UBI/UBIFS) images from the bundle ---"
    find "$deploy" \( -name '*.ubi' -o -name '*.ubifs' -o -name '*nand*' \) -print -delete 2>/dev/null || true
    echo "--- deploy size after NAND prune ---"; du -sh "$deploy" 2>/dev/null || true

    # SD-card (OP-TEE) FlashLayout for the README's worked example.
    local tsv
    tsv="$( { find "$deploy" -path "*flashlayout*/optee/FlashLayout_sdcard_${board}-optee.tsv"; \
              find "$deploy" -path "*flashlayout*sdcard*${board}*.tsv"; } 2>/dev/null \
            | sed "s#^${deploy}/##" | head -n1)"
    echo "${board} SD-card FlashLayout: ${tsv:-<not found -- see the .tsv list above>}"

    mkdir -p "$ARTIFACT_DIR"

    # README written into the deploy dir so it lands at the root of the bundle.
    local title="Flashing the ${machine^^} Slint demo image"
    local rule="${title//?/=}"
    cat > "$deploy/README.txt" <<EOF
$title
$rule

This is the OpenSTLinux "images" directory for MACHINE=$machine -- the same
layout ST ships in its Starter Package. The flashlayout_* directory holds one
FlashLayout .tsv per board and boot scheme (SD card / eMMC / NOR), all sharing a
single root filesystem, so this one bundle covers every board of the $machine
family. The image boots straight into the Slint demo on the display (LinuxKMS
backend).

STM32MP boards are programmed over USB with STMicroelectronics'
STM32CubeProgrammer, driven by a FlashLayout .tsv that lists the partitions and
the binaries (paths relative to this directory) to write.

1. Install STM32CubeProgrammer (provides STM32_Programmer_CLI):
     https://www.st.com/en/development-tools/stm32cubeprog.html
2. Extract this bundle:
     tar xzf ${machine}-flash-bundle.tar.gz
3. ${boot_note}
4. Flash, pointing -w at the .tsv that matches your board and target storage.
   Example -- ${board}, SD card, OP-TEE boot scheme:
     STM32_Programmer_CLI -c port=usb1 -w ${tsv:-flashlayout_st-image-slint-demos/optee/FlashLayout_sdcard_${board}-optee.tsv}
   For another board/storage, list the available layouts and pick one:
     ls flashlayout_*/optee
5. Set the boot switches back to boot from the flashed media and power-cycle.
EOF

    tar -czf "$ARTIFACT_DIR/${machine}-flash-bundle.tar.gz" -C "$deploy" .
    # Also publish the README standalone so it's readable without the multi-GB download.
    cp "$deploy/README.txt" "$ARTIFACT_DIR/${machine}-flash-bundle-README.txt"
    echo "Wrote ${machine}-flash-bundle.tar.gz (README.txt inside) and ${machine}-flash-bundle-README.txt"
}
