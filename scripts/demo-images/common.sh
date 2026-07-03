#!/bin/bash
# Shared helpers for the per-device Slint demo image builds.
#
# This file is meant to be *sourced* by a per-device script (e.g.
# imx95-evk.sh). It only defines functions; the device script owns the
# `set -e` / control flow.

# Make sure Google's `repo` tool is available (NXP's BSP is consumed via a
# repo manifest). Installs a private copy into ~/.local/bin if missing.
slint_demo_ensure_repo_tool() {
    if command -v repo >/dev/null 2>&1; then
        return 0
    fi
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo \
        -o "$HOME/.local/bin/repo"
    chmod a+x "$HOME/.local/bin/repo"
    export PATH="$HOME/.local/bin:$PATH"
}

# Add a layer only if it isn't already part of the build configuration. NXP's
# i.MX BSP, for example, already ships and enables meta-clang, so adding our
# own copy would trigger a duplicate BBFILE_COLLECTIONS parse error.
slint_demo_add_layer_if_missing() {
    local layer_path="$1"
    if bitbake-layers show-layers 2>/dev/null | grep -Fq "$layer_path"; then
        echo "Layer already present, skipping add: $layer_path"
        return 0
    fi
    bitbake-layers add-layer "$layer_path"
}

# `repo` refuses to run without a git identity. Set a placeholder one only if
# the environment doesn't already provide it.
slint_demo_ensure_git_identity() {
    git config --global user.name  >/dev/null 2>&1 || git config --global user.name  "Slint CI"
    git config --global user.email >/dev/null 2>&1 || git config --global user.email "ci@slint.dev"
    git config --global color.ui false || true
}

# Append the configuration shared across every demo-image device to the given
# conf/local.conf. Covers two things: the Slint build feature set and
# aggressive disk-space conservation.
#
# Note: there is deliberately no public sstate mirror here. NXP's i.MX BSP
# does not publish one, and the upstream poky/oe-core mirror doesn't match a
# vendor BSP's metadata, so everything is built locally.
slint_demo_configure_local_conf() {
    local conf="$1"
    cat >> "$conf" <<'EOF'

# --- Slint demo image: shared configuration (scripts/demo-images/common.sh) ---

# clang is required for the Skia renderer.
CLANGSDK = "1"

# Render the demos directly on the framebuffer via KMS/DRM with the Skia
# renderer, and ship the system-testing harness.
PACKAGECONFIG:append:pn-slint-cpp = " backend-linuxkms renderer-skia system-testing"

# --- Disk-space conservation ---

# Delete each recipe's WORKDIR as soon as it has been built. This is the single
# biggest disk saver for a full vendor BSP image build; deploy artifacts under
# DEPLOY_DIR_IMAGE are kept.
INHERIT += "rm_work"

# Don't keep a per-recipe copy of fetched sources around in sstate tarballs.
BB_GENERATE_MIRROR_TARBALLS = "0"

# Stop scheduling new tasks (and abort outright) before the runner's disk
# fills up, so a low-disk condition fails cleanly instead of corrupting state.
BB_DISKMON_DIRS = "\
    STOPTASKS,${TMPDIR},2G,100K \
    STOPTASKS,${DL_DIR},2G,100K \
    STOPTASKS,${SSTATE_DIR},2G,100K \
    ABORT,${TMPDIR},512M,1K \
    ABORT,${DL_DIR},512M,1K \
    ABORT,${SSTATE_DIR},512M,1K"

# --- Runner resource caps (Hetzner) ---
# These two knobs carry very different memory risk, so keep them decoupled:
#  - PARALLEL_MAKE is make-parallelism *within* one recipe. Compiling
#    clang-native is the build's long pole (over an hour at -j4); -j8 speeds it
#    up and 8 parallel compiles fit comfortably in the box's 32G RAM.
#  - BB_NUMBER_THREADS is how many *recipes* build at once -- the real OOM
#    lever, since it lets clang's heavy jobs collide with a rust/LTO link from
#    another recipe. Keep it at the proven 4 to bound peak memory.
# CARGO_BUILD_JOBS stays low because rustc + LTO linking the slint crate graph
# can spike multiple GB per job.
BB_NUMBER_THREADS = "4"
PARALLEL_MAKE = "-j 8"
export CARGO_BUILD_JOBS = "2"
EOF
}

# Copy the given files into $ARTIFACT_DIR so a later workflow step can publish
# them to the demo-images release. Missing globs are skipped with a warning;
# erroring if nothing was collected. Optionally:
#   ARTIFACT_DIR        - directory to copy the flashable artifacts into (required)
#   ARTIFACT_BASENAME   - if set, each file is renamed to
#                         "<ARTIFACT_BASENAME>.<label>.<xz|zst|bmap|...>".
#                         OpenEmbedded stamps its deploy files with a build date,
#                         so a stable name is what lets `gh release upload
#                         --clobber` replace the previous asset in place instead
#                         of piling up date-stamped files on the release.
#   ARTIFACT_IMAGE_LABEL - the extension label to give the raw image (default
#                         "wic"). A .wic is a plain raw disk image, so the Pi
#                         builds relabel it to "img" -- the extension flashing
#                         tools (balenaEtcher, Raspberry Pi Imager) expect.
slint_demo_collect_artifacts() {
    local dest="${ARTIFACT_DIR:?ARTIFACT_DIR must be set}"
    local label="${ARTIFACT_IMAGE_LABEL:-wic}"
    mkdir -p "$dest"
    local f base target collected=0
    for f in "$@"; do
        if [ ! -e "$f" ]; then
            echo "warning: no artifact matched '$f', skipping" >&2
            continue
        fi
        base="$(basename "$f")"
        if [ -n "${ARTIFACT_BASENAME:-}" ]; then
            # Keep the compression/type suffix (everything after the first
            # ".wic") but swap the "wic" label, e.g. foo.rootfs.wic.xz ->
            # <basename>.img.xz, foo.rootfs.wic.bmap -> <basename>.img.bmap.
            target="$dest/${ARTIFACT_BASENAME}.${label}${base#*.wic}"
        else
            target="$dest/$base"
        fi
        echo "Collecting $base -> $target"
        cp -L "$f" "$target"
        collected=$((collected + 1))
    done
    if [ "$collected" -eq 0 ]; then
        echo "error: no artifacts were collected" >&2
        return 1
    fi
}
