#!/bin/bash
# Build the Slint demo image for the NXP i.MX95 19x19 LPDDR5 EVK and collect the
# flashable artifacts into $ARTIFACT_DIR for the workflow to publish.
#
# The i.MX95 BSP only ships as an NXP `repo` manifest, so -- unlike the
# qemuarm64 CI which bootstraps with bitbake-setup -- we fetch the BSP that
# way. We pin a stable NXP release from the `imx-linux-scarthgap` branch
# (Yocto 5.0 LTS), which matches meta-slint's main branch (scarthgap-compatible).
#
# Overridable via the environment:
#   IMX_MANIFEST_BRANCH  default imx-linux-scarthgap
#   IMX_MANIFEST_FILE    default imx-6.6.52-2.2.2.xml
#   MACHINE              default imx95-19x19-lpddr5-evk
#   DISTRO               default fsl-imx-wayland
#   IMAGE                default imx-image-slint-demos
#   WORK_ROOT            default $PWD (build tree is created here)
#   ARTIFACT_DIR         default $WORK_ROOT/artifacts (flashable image copied here)
#   SSTATE_DIR           unset (bitbake default); set to a persistent path to
#                        reuse an sstate cache across builds
set -euo pipefail

IMX_MANIFEST_BRANCH="${IMX_MANIFEST_BRANCH:-imx-linux-scarthgap}"
IMX_MANIFEST_FILE="${IMX_MANIFEST_FILE:-imx-6.6.52-2.2.2.xml}"
MACHINE="${MACHINE:-imx95-19x19-lpddr5-evk}"
DISTRO="${DISTRO:-fsl-imx-wayland}"
IMAGE="${IMAGE:-imx-image-slint-demos}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# scripts/demo-images/<this> -> repo root is two levels up.
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

# --- Fetch the NXP i.MX BSP via repo. ---
repo init -u https://github.com/nxp-imx/imx-manifest \
    -b "$IMX_MANIFEST_BRANCH" -m "$IMX_MANIFEST_FILE" --no-clone-bundle
repo sync -j"$(nproc)" --no-clone-bundle

# --- Set up the build directory. ---
# imx-setup-release.sh is a sourced script that relies on a number of unset
# variables and non-zero returns, so relax the shell's strict flags while it
# runs. EULA=1 accepts the NXP end-user license non-interactively.
set +eu
EULA=1 MACHINE="$MACHINE" DISTRO="$DISTRO" source ./imx-setup-release.sh -b build
set -eu

# imx-setup-release.sh leaves us inside the build directory.

# --- Add meta-clang and meta-slint on top of the NXP layers. ---
# The NXP i.MX BSP already ships and enables meta-clang, so only clone and add
# our own copy if this BSP doesn't already provide one (adding a duplicate
# trips a "duplicated BBFILE_COLLECTIONS 'clang-layer'" parse error).
META_CLANG_DIR="$WORK_ROOT/sources/meta-clang"
if ! bitbake-layers show-layers 2>/dev/null | grep -Fq "/meta-clang"; then
    if [ ! -d "$META_CLANG_DIR" ]; then
        git clone -b scarthgap https://github.com/kraj/meta-clang.git "$META_CLANG_DIR"
    fi
    bitbake-layers add-layer "$META_CLANG_DIR"
else
    echo "meta-clang already provided by the BSP, skipping"
fi

# meta-slint (scarthgap) depends on meta-rust-bin's "rust-bin-layer" for the
# prebuilt Rust toolchain. The NXP BSP uses oe-core's Rust and doesn't ship it,
# so add it ourselves, before meta-slint, unless the BSP already provides it.
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

# --- Slint / disk-conservation configuration. ---
slint_demo_configure_local_conf conf/local.conf

# Point sstate at a persistent cache (e.g. a mounted Hetzner Volume) when the
# workflow provides one; DL_DIR is deliberately left at its default so downloads
# stay ephemeral. A warm sstate restores most recipes without re-fetching.
if [ -n "${SSTATE_DIR:-}" ]; then
    echo "SSTATE_DIR = \"$SSTATE_DIR\"" >> conf/local.conf
fi

# --- Build. ---
bitbake "$IMAGE"

# --- Collect the flashable image for the workflow to publish as an artifact. ---
# Ship the compressed image plus its block map; bmaptool can flash the .wic.zst
# directly using the .bmap. Match by extension rather than guessing the full
# file name: OpenEmbedded adds an infix (e.g. ".rootfs") and the exact name
# varies by release. Restrict to regular files so OE's convenience symlinks
# don't duplicate the (large) image in the artifact.
DEPLOY="tmp/deploy/images/$MACHINE"
mapfile -t SLINT_DEMO_IMAGES < <(
    find "$DEPLOY" -maxdepth 1 -type f \( -name '*.wic.zst' -o -name '*.wic.bmap' \) | sort
)
slint_demo_collect_artifacts "${SLINT_DEMO_IMAGES[@]}"
