#!/bin/bash
# Shared build for the Renesas RZ Slint demo images (RZ/G3E, RZ/G3L). The
# per-board wrapper (rzg3e.sh, rzg3l.sh) sets MACHINE, the board description and
# the BSP pins, then calls slint_demo_build_rz; the rest is common.
#
# Almost all of the BSP is public: meta-renesas is on GitHub, and poky, meta-arm
# and meta-openembedded are pinned to the exact revisions Renesas tested (taken
# from their README / the RZ Linux BSP Plus build page, see the wrappers).
#
# The one piece that is not public is the proprietary graphics package
# (meta-rz-features, the Mali userspace), which Renesas only hands out after a
# licence agreement. It is fetched from an internal mirror, whose URL comes from
# a repository secret -- see GRAPHICS_URL below. The URL is never printed: on
# failure we report the curl exit code only.
#
# Env: GRAPHICS_URL or GRAPHICS_URL_FILE (required); MACHINE, BOARD_DESC,
# META_SLINT_DIR, META_RENESAS_TAG, POKY_REV, META_ARM_REV, META_OE_REV,
# TEMPLATECONF_SUBDIR, GRAPHICS_ARCHIVE, GRAPHICS_SHA256 (set by the wrapper);
# DISTRO, IMAGE, WORK_ROOT, ARTIFACT_DIR, SSTATE_DIR (optional).

# Clone <dir> from <url> at <rev> (a commit, tag or branch), unless it's there.
_slint_demo_rz_clone() {
    local dir="$1" url="$2" rev="$3"
    if [ ! -d "$dir" ]; then
        git clone "$url" "$dir"
        # A bare branch name is not a local ref after cloning, so git would try
        # to create a branch for it -- which it refuses to do with --detach
        # ("'--detach' cannot be used with '-b'"). Resolve branches through
        # origin/, and fall back to the literal ref for tags and commits.
        git -C "$dir" checkout --detach "origin/$rev" 2>/dev/null \
            || git -C "$dir" checkout --detach "$rev"
    fi
}

# Download and unpack the proprietary graphics package into <work_root>.
_slint_demo_rz_fetch_graphics() {
    local work_root="$1" archive="$2" sha256="$3"

    # Read the download URL from a private file when one is given (the workflow
    # hands it over that way so the secret never reaches the process command
    # line), else from the environment.
    if [ -n "${GRAPHICS_URL_FILE:-}" ] && [ -r "${GRAPHICS_URL_FILE}" ]; then
        GRAPHICS_URL="$(cat "$GRAPHICS_URL_FILE")"
    fi
    : "${GRAPHICS_URL:?the RZ graphics package URL is not set (see the graphics URL secret in the workflow)}"

    if [ ! -d "$work_root/meta-rz-features" ]; then
        echo "Downloading the RZ graphics package ($archive)"
        # Deliberately quiet: curl's messages can echo the URL, which is a
        # secret. Report only the exit code on failure.
        if ! curl --fail --silent --show-error --location \
                -o "$archive" "$GRAPHICS_URL" 2>/dev/null; then
            echo "::error::could not download the RZ graphics package (curl failed; URL withheld). Check the graphics URL secret."
            exit 1
        fi
        # Pinned checksum: catches a truncated download or a swapped file -- most
        # often a URL that serves an HTML page instead of the file (curl still gets
        # a 200, so only the checksum notices).
        if ! echo "${sha256}  ${archive}" | sha256sum -c - >/dev/null 2>&1; then
            echo "::error::the downloaded graphics package does not match the expected checksum."
            # Describe what we actually got. Deliberately no content and no URL: an
            # HTML page would echo parts of the secret URL back into the log.
            echo "  expected sha256: ${sha256}"
            echo "  actual   sha256: $(sha256sum "$archive" | cut -d' ' -f1)"
            echo "  size:            $(stat -c %s "$archive") bytes"
            echo "  type:            $(file -b "$archive" 2>/dev/null || echo unknown)"
            echo "  If the type is HTML, the secret points at a landing page rather than"
            echo "  the file itself -- it needs to be a direct download URL."
            rm -f "$archive"
            exit 1
        fi
        tar xf "$archive"
        rm -f "$archive"
    fi
    if [ ! -d "$work_root/meta-rz-features/meta-rz-graphics" ]; then
        echo "::error::meta-rz-features/meta-rz-graphics not found after extracting $archive"
        find "$work_root/meta-rz-features" -maxdepth 2 2>/dev/null | head -20 || true
        exit 1
    fi
}

slint_demo_build_rz() {
    local machine="${MACHINE:?set by the caller, e.g. smarc-rzg3l}"
    local board_desc="${BOARD_DESC:-Renesas $machine}"
    local distro="${DISTRO:-rz-vlp}"
    local image="${IMAGE:-core-image-slint-demos}"
    local meta_slint_dir="${META_SLINT_DIR:?set by the caller}"

    # BSP pins -- all set by the wrapper, which documents where they come from.
    local meta_renesas_tag="${META_RENESAS_TAG:?set by the caller}"
    local poky_rev="${POKY_REV:?set by the caller}"
    local meta_arm_rev="${META_ARM_REV:?set by the caller}"
    local meta_oe_rev="${META_OE_REV:?set by the caller}"
    # Renesas' conf template, relative to meta-renesas (the BSP lines differ).
    local templateconf_subdir="${TEMPLATECONF_SUBDIR:?set by the caller}"
    local graphics_archive="${GRAPHICS_ARCHIVE:?set by the caller}"
    local graphics_sha256="${GRAPHICS_SHA256:?set by the caller}"

    local work_root="${WORK_ROOT:-$PWD}"
    export ARTIFACT_DIR="${ARTIFACT_DIR:-$work_root/artifacts}"
    mkdir -p "$work_root"
    cd "$work_root"

    slint_demo_ensure_git_identity

    # --- The proprietary graphics package -----------------------------------
    _slint_demo_rz_fetch_graphics "$work_root" "$graphics_archive" "$graphics_sha256"

    # --- The public layers --------------------------------------------------
    _slint_demo_rz_clone "$work_root/poky"              https://git.yoctoproject.org/poky              "$poky_rev"
    _slint_demo_rz_clone "$work_root/meta-arm"          https://git.yoctoproject.org/meta-arm          "$meta_arm_rev"
    _slint_demo_rz_clone "$work_root/meta-openembedded" https://github.com/openembedded/meta-openembedded.git "$meta_oe_rev"
    _slint_demo_rz_clone "$work_root/meta-renesas"      https://github.com/renesas-rz/meta-renesas.git "$meta_renesas_tag"
    _slint_demo_rz_clone "$work_root/meta-clang"        https://github.com/kraj/meta-clang.git         scarthgap
    if [ ! -d "$work_root/meta-rust-bin" ]; then
        # meta-rust-bin tracks master (no per-release branches).
        git clone https://github.com/rust-embedded/meta-rust-bin.git "$work_root/meta-rust-bin"
    fi

    # Renesas' conf template seeds bblayers.conf with poky, meta-oe/-python/
    # -multimedia, meta-arm and the two meta-renesas layers, so only our extras and
    # the graphics layer need adding. oe-init-build-env touches unset vars / returns
    # non-zero, so relax strict mode across it.
    set +eu
    TEMPLATECONF="$work_root/meta-renesas/$templateconf_subdir" \
        source "$work_root/poky/oe-init-build-env" "$work_root/build"
    set -eu

    bitbake-layers add-layer "$work_root/meta-rz-features/meta-rz-graphics"
    bitbake-layers add-layer "$work_root/meta-clang"
    # meta-slint LAYERDEPENDS on rust-bin-layer, so meta-rust-bin goes first.
    bitbake-layers add-layer "$work_root/meta-rust-bin"
    slint_demo_add_layer_if_missing "$meta_slint_dir"

    echo "MACHINE = \"$machine\"" >> conf/local.conf
    echo "DISTRO ?= \"$distro\"" >> conf/local.conf
    cat >> conf/local.conf <<'EOF'

# KMS/DRM demo rendered fullscreen via Slint's linuxkms backend, no compositor.
# opengl is required at build time -- Skia always links GL.
DISTRO_FEATURES:append = " opengl"
DISTRO_FEATURES:remove = " x11"

# The rz-vlp distro ships compressed/tar image types, which leaves no plain .wic
# to relabel as the .img we publish. Ask for the uncompressed one as well.
IMAGE_FSTYPES:append = " wic"
EOF
    slint_demo_configure_local_conf conf/local.conf

    bitbake "$image"

    # Ship the raw image, relabelled .wic -> .img. Match by extension (OE adds a
    # ".rootfs" infix); regular files only, so OE's symlink doesn't duplicate it.
    export ARTIFACT_IMAGE_LABEL=img
    local deploy
    deploy="$(bitbake -e "$image" 2>/dev/null | sed -n 's/^DEPLOY_DIR_IMAGE="\(.*\)"$/\1/p' | tail -n1)"
    if [ -z "$deploy" ] || [ ! -d "$deploy" ]; then
        deploy="$(find "$work_root/build" -type d -path "*/deploy/images/$machine" 2>/dev/null | head -n1)"
    fi
    if [ -z "$deploy" ] || [ ! -d "$deploy" ]; then
        echo "::error::could not locate the image deploy dir for $machine"
        exit 1
    fi
    echo "Image deploy dir: $deploy"
    local images
    mapfile -t images < <(find "$deploy" -maxdepth 1 -type f -name '*.wic' | sort)
    if [ "${#images[@]}" -eq 0 ]; then
        echo "::error::no .wic image found in $deploy -- the distro's IMAGE_FSTYPES may not include an uncompressed wic. Deploy dir contains:"
        find "$deploy" -maxdepth 1 -type f -printf '  %10s %f\n' | sort -k2 || true
        exit 1
    fi
    slint_demo_collect_artifacts "${images[@]}"

    local artifact_basename="${ARTIFACT_BASENAME:-${machine}-slint-demo}"
    local title="Slint demo image for the $board_desc"
    local rule="${title//?/=}"
    cat > "$ARTIFACT_DIR/README.txt" <<EOF
$title
$rule

This image boots straight into the Slint demo, rendered on the display via
KMS/DRM.

Contents of ${artifact_basename}.zip:
  ${artifact_basename}.img   a raw SD-card image (boot + root partitions)
  README.txt                 this file

Flashing an SD card
-------------------
  unzip ${artifact_basename}.zip
  sudo dd if=${artifact_basename}.img of=/dev/sdX bs=4M conv=fsync status=progress
(replace /dev/sdX with your SD card device)

First boot
----------
Set the board's boot switches to SD-card boot, insert the card, connect a
display and power on. The Slint demo starts automatically.

Networking
----------
  * Wired Ethernet comes up automatically via DHCP.
  * An SSH server is running on port 22 (set a root password or key to log in).
EOF
    echo "Wrote README.txt"
}
