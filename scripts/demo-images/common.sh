#!/bin/bash
# Shared helpers, sourced by a per-device script (e.g. imx95-evk.sh). Only
# defines functions; the device script owns set -e / control flow.

# Install Google's `repo` (used to fetch vendor BSPs) into ~/.local/bin if missing.
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

# Add a layer only if not already present (some BSPs ship meta-clang etc., and a
# duplicate would be a BBFILE_COLLECTIONS parse error).
slint_demo_add_layer_if_missing() {
    local layer_path="$1"
    if bitbake-layers show-layers 2>/dev/null | grep -Fq "$layer_path"; then
        echo "Layer already present, skipping add: $layer_path"
        return 0
    fi
    bitbake-layers add-layer "$layer_path"
}

# `repo` refuses to run without a git identity; set a placeholder if unset.
slint_demo_ensure_git_identity() {
    git config --global user.name  >/dev/null 2>&1 || git config --global user.name  "Slint CI"
    git config --global user.email >/dev/null 2>&1 || git config --global user.email "ci@slint.dev"
    git config --global color.ui false || true
}

# Append the config shared across every demo-image device to conf/local.conf:
# the Slint feature set and disk-space conservation.
slint_demo_configure_local_conf() {
    local conf="$1"
    cat >> "$conf" <<'EOF'

# --- Slint demo image: shared configuration (scripts/demo-images/common.sh) ---

# clang is required for the Skia renderer.
CLANGSDK = "1"

# KMS/DRM framebuffer + Skia renderer, plus the system-testing harness.
PACKAGECONFIG:append:pn-slint-cpp = " backend-linuxkms renderer-skia system-testing"

# The demo images don't ship an SBOM; skip SPDX generation.
INHERIT:remove = "create-spdx"

# --- Disk-space conservation ---

# Delete each recipe's WORKDIR once built (biggest disk saver; deploy is kept).
INHERIT += "rm_work"
BB_GENERATE_MIRROR_TARBALLS = "0"

# Abort cleanly before the runner's disk fills, rather than corrupting state.
BB_DISKMON_DIRS = "\
    STOPTASKS,${TMPDIR},2G,100K \
    STOPTASKS,${DL_DIR},2G,100K \
    STOPTASKS,${SSTATE_DIR},2G,100K \
    HALT,${TMPDIR},512M,1K \
    HALT,${DL_DIR},512M,1K \
    HALT,${SSTATE_DIR},512M,1K"

# Resource caps for the Hetzner box (32G RAM). BB_NUMBER_THREADS is the OOM lever
# (parallel recipes), so keep it low; PARALLEL_MAKE speeds up the clang-native
# long pole. CARGO_BUILD_JOBS bounds cargo/rustc and Skia's internal ninja (it
# reads NUM_JOBS, which cargo derives from this); the Slint+Skia graph is the
# long pole, so give it a few jobs. LTO is off in those recipes, which keeps the
# peak RAM of the parallel Skia C++ compiles in check.
BB_NUMBER_THREADS = "4"
PARALLEL_MAKE = "-j 8"
export CARGO_BUILD_JOBS = "6"
EOF

    # Reuse a persistent sstate cache (the shared Hetzner Volume) when provided.
    if [ -n "${SSTATE_DIR:-}" ]; then
        echo "SSTATE_DIR = \"$SSTATE_DIR\"" >> "$conf"
        # Hash equivalence keys sstate by a unihash whose taskhash->unihash map
        # lives in a database. Keep that database next to the shared sstate rather
        # than in the ephemeral build dir (bitbake's default), so the mappings
        # persist across builds -- otherwise every build computes fresh unihashes
        # and nothing on the Volume matches, defeating sstate reuse entirely.
        echo 'BB_HASHSERVE_DB_DIR = "${SSTATE_DIR}"' >> "$conf"
    fi

    # No public sstate mirror: it can't be used together with our local hash
    # equivalence server (unihashes don't line up with the mirror's), so bitbake
    # warns and its mismatched restore probes surface as setscene errors -- and it
    # never provided hits for this vendor-BSP config anyway. Our own Volume
    # (SSTATE_DIR + a shared hashserv DB) is the sstate cache.
}

# Copy the given files into $ARTIFACT_DIR for a later workflow step to publish.
# Missing globs warn; errors if nothing was collected. Optional:
#   ARTIFACT_BASENAME    - rename each to "<basename>.<label><suffix-after-.wic>",
#                          giving a stable name so `gh release upload --clobber`
#                          replaces the previous (date-stamped) asset in place.
#   ARTIFACT_IMAGE_LABEL - extension label for the raw image (default "wic"; the
#                          Pi builds relabel .wic -> .img for their flashers).
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
            # Swap the "wic" label, keep the suffix after it (foo.rootfs.wic.xz
            # -> <basename>.img.xz).
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
