#!/bin/bash
# Build the Slint demo image for the Renesas RZ/G3E SMARC EVK.
#
# Almost all of the BSP is public: meta-renesas is on GitHub, and poky, meta-arm
# and meta-openembedded are pinned to the exact revisions Renesas tested (taken
# from their README / kas configs, see the constants below).
#
# The one piece that is not public is the proprietary graphics package
# (meta-rz-features, the Mali userspace), which Renesas only hands out after a
# licence agreement. It is fetched from an internal mirror, whose URL comes from
# a repository secret -- see RZG3E_GRAPHICS_URL below. The URL is never printed:
# on failure we report the curl exit code only.
#
# Env: RZG3E_GRAPHICS_URL or RZG3E_GRAPHICS_URL_FILE (required); MACHINE, DISTRO,
# IMAGE, WORK_ROOT, ARTIFACT_DIR, SSTATE_DIR (optional).
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

# Proprietary graphics package (fetched from the internal mirror, see above).
GRAPHICS_ARCHIVE="${GRAPHICS_ARCHIVE:-meta-rz-features_graphics_v4.2.0.2.tar.gz}"
GRAPHICS_SHA256="${GRAPHICS_SHA256:-37118a4f103b79c748fea6ba4d013d8c4a1807137a54f83be668235206a5ad22}"

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

# --- The proprietary graphics package ---------------------------------------
# Read the download URL from a private file when one is given (the workflow hands
# it over that way so the secret never reaches the process command line), else
# from the environment.
if [ -n "${RZG3E_GRAPHICS_URL_FILE:-}" ] && [ -r "${RZG3E_GRAPHICS_URL_FILE}" ]; then
    RZG3E_GRAPHICS_URL="$(cat "$RZG3E_GRAPHICS_URL_FILE")"
fi
: "${RZG3E_GRAPHICS_URL:?the RZ/G3E graphics package URL is not set (see the graphics URL secret in the workflow)}"

if [ ! -d "$WORK_ROOT/meta-rz-features" ]; then
    echo "Downloading the RZ/G3E graphics package ($GRAPHICS_ARCHIVE)"
    # Deliberately quiet: curl's messages can echo the URL, which is a secret.
    # Report only the exit code on failure.
    if ! curl --fail --silent --show-error --location \
            -o "$GRAPHICS_ARCHIVE" "$RZG3E_GRAPHICS_URL" 2>/dev/null; then
        echo "::error::could not download the RZ/G3E graphics package (curl failed; URL withheld). Check the graphics URL secret."
        exit 1
    fi
    # Pinned checksum: catches a truncated download or a swapped file -- most
    # often a URL that serves an HTML page instead of the file (curl still gets
    # a 200, so only the checksum notices).
    if ! echo "${GRAPHICS_SHA256}  ${GRAPHICS_ARCHIVE}" | sha256sum -c - >/dev/null 2>&1; then
        echo "::error::the downloaded graphics package does not match the expected checksum."
        # Describe what we actually got. Deliberately no content and no URL: an
        # HTML page would echo parts of the secret URL back into the log.
        echo "  expected sha256: ${GRAPHICS_SHA256}"
        echo "  actual   sha256: $(sha256sum "$GRAPHICS_ARCHIVE" | cut -d' ' -f1)"
        echo "  size:            $(stat -c %s "$GRAPHICS_ARCHIVE") bytes"
        echo "  type:            $(file -b "$GRAPHICS_ARCHIVE" 2>/dev/null || echo unknown)"
        echo "  If the type is HTML, the secret points at a landing page rather than"
        echo "  the file itself -- it needs to be a direct download URL."
        rm -f "$GRAPHICS_ARCHIVE"
        exit 1
    fi
    tar xf "$GRAPHICS_ARCHIVE"
    rm -f "$GRAPHICS_ARCHIVE"
fi
if [ ! -d "$WORK_ROOT/meta-rz-features/meta-rz-graphics" ]; then
    echo "::error::meta-rz-features/meta-rz-graphics not found after extracting $GRAPHICS_ARCHIVE"
    find "$WORK_ROOT/meta-rz-features" -maxdepth 2 2>/dev/null | head -20 || true
    exit 1
fi

# --- The public layers ------------------------------------------------------
_rz_clone() {  # _rz_clone <dir> <url> <rev>   rev: commit, tag or branch
    local dir="$WORK_ROOT/$1"
    if [ ! -d "$dir" ]; then
        git clone "$2" "$dir"
        # A bare branch name is not a local ref after cloning, so git would try
        # to create a branch for it -- which it refuses to do with --detach
        # ("'--detach' cannot be used with '-b'"). Resolve branches through
        # origin/, and fall back to the literal ref for tags and commits.
        git -C "$dir" checkout --detach "origin/$3" 2>/dev/null \
            || git -C "$dir" checkout --detach "$3"
    fi
}
_rz_clone poky              https://git.yoctoproject.org/poky              "$POKY_REV"
_rz_clone meta-arm          https://git.yoctoproject.org/meta-arm          "$META_ARM_REV"
_rz_clone meta-openembedded https://github.com/openembedded/meta-openembedded.git "$META_OE_REV"
_rz_clone meta-renesas      https://github.com/renesas-rz/meta-renesas.git "$META_RENESAS_TAG"
_rz_clone meta-clang        https://github.com/kraj/meta-clang.git         scarthgap
if [ ! -d "$WORK_ROOT/meta-rust-bin" ]; then
    # meta-rust-bin tracks master (no per-release branches).
    git clone https://github.com/rust-embedded/meta-rust-bin.git "$WORK_ROOT/meta-rust-bin"
fi

# Renesas' conf template seeds bblayers.conf with poky, meta-oe/-python/
# -multimedia, meta-arm and the two meta-renesas layers, so only our extras and
# the graphics layer need adding. oe-init-build-env touches unset vars / returns
# non-zero, so relax strict mode across it.
set +eu
TEMPLATECONF="$WORK_ROOT/meta-renesas/meta-rz-distro/conf/templates/rz-conf/" \
    source "$WORK_ROOT/poky/oe-init-build-env" "$WORK_ROOT/build"
set -eu

bitbake-layers add-layer "$WORK_ROOT/meta-rz-features/meta-rz-graphics"
bitbake-layers add-layer "$WORK_ROOT/meta-clang"
# meta-slint LAYERDEPENDS on rust-bin-layer, so meta-rust-bin goes first.
bitbake-layers add-layer "$WORK_ROOT/meta-rust-bin"
slint_demo_add_layer_if_missing "$META_SLINT_DIR"

echo "MACHINE = \"$MACHINE\"" >> conf/local.conf
echo "DISTRO ?= \"$DISTRO\"" >> conf/local.conf
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

bitbake "$IMAGE"

# Ship the raw image, relabelled .wic -> .img. Match by extension (OE adds a
# ".rootfs" infix); regular files only, so OE's symlink doesn't duplicate it.
export ARTIFACT_IMAGE_LABEL=img
DEPLOY="$(bitbake -e "$IMAGE" 2>/dev/null | sed -n 's/^DEPLOY_DIR_IMAGE="\(.*\)"$/\1/p' | tail -n1)"
if [ -z "$DEPLOY" ] || [ ! -d "$DEPLOY" ]; then
    DEPLOY="$(find "$WORK_ROOT/build" -type d -path "*/deploy/images/$MACHINE" 2>/dev/null | head -n1)"
fi
if [ -z "$DEPLOY" ] || [ ! -d "$DEPLOY" ]; then
    echo "::error::could not locate the image deploy dir for $MACHINE"
    exit 1
fi
echo "Image deploy dir: $DEPLOY"
mapfile -t IMAGES < <(find "$DEPLOY" -maxdepth 1 -type f -name '*.wic' | sort)
if [ "${#IMAGES[@]}" -eq 0 ]; then
    echo "::error::no .wic image found in $DEPLOY -- the distro's IMAGE_FSTYPES may not include an uncompressed wic. Deploy dir contains:"
    find "$DEPLOY" -maxdepth 1 -type f -printf '  %10s %f\n' | sort -k2 || true
    exit 1
fi
slint_demo_collect_artifacts "${IMAGES[@]}"

ARTIFACT_BASENAME="${ARTIFACT_BASENAME:-${MACHINE}-slint-demo}"
TITLE="Slint demo image for the $BOARD_DESC"
RULE="${TITLE//?/=}"
cat > "$ARTIFACT_DIR/README.txt" <<EOF
$TITLE
$RULE

This image boots straight into the Slint demo, rendered on the display via
KMS/DRM.

Contents of ${ARTIFACT_BASENAME}.zip:
  ${ARTIFACT_BASENAME}.img   a raw SD-card image (boot + root partitions)
  README.txt                 this file

Flashing an SD card
-------------------
  unzip ${ARTIFACT_BASENAME}.zip
  sudo dd if=${ARTIFACT_BASENAME}.img of=/dev/sdX bs=4M conv=fsync status=progress
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
