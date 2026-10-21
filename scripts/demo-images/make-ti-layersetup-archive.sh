#!/bin/bash
# Build the oe-layersetup archive the TI demo-image builds fall back to when
# git.ti.com is unreachable (see _slint_demo_ti_fetch_layersetup in
# ti-common.sh). Run it on a machine that can reach git.ti.com, upload the
# archive to Nextcloud, and put its share link (a direct download link) in the
# NEXTCLOUD_URL_TI_OE_LAYERSETUP repository secret.
#
# The archive is a `git archive` of the commit ti-common.sh pins, gzipped
# without a timestamp, so it comes out byte-identical from any clone and its
# checksum stays the one pinned in ti-common.sh. When you bump the commit, put
# the checksum this prints into SLINT_DEMO_TI_LAYERSETUP_ARCHIVE_SHA256.
#
# Usage: make-ti-layersetup-archive.sh [output-dir]
# Env overrides: OE_LAYERSETUP_URL, OE_LAYERSETUP_REV.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/demo-images/ti-common.sh
. "$SCRIPT_DIR/ti-common.sh"

url="${OE_LAYERSETUP_URL:-https://git.ti.com/git/arago-project/oe-layersetup.git}"
rev="${OE_LAYERSETUP_REV:-$SLINT_DEMO_TI_LAYERSETUP_REV}"
out_dir="$(cd "${1:-.}" && pwd)"
archive="$out_dir/oe-layersetup-${rev:0:12}.tar.gz"

clone="$(mktemp -d)"
trap 'rm -rf "$clone"' EXIT
git clone --quiet --bare "$url" "$clone/oe-layersetup.git"
git -C "$clone/oe-layersetup.git" archive --format=tar --prefix=oe-layersetup/ "$rev" \
    | gzip -n -9 > "$archive"

sha256="$(sha256sum "$archive" | cut -d' ' -f1)"
echo "Wrote $archive"
echo "sha256: $sha256"
if [ "$rev" = "$SLINT_DEMO_TI_LAYERSETUP_REV" ] && [ "$sha256" != "$SLINT_DEMO_TI_LAYERSETUP_ARCHIVE_SHA256" ]; then
    echo "warning: this doesn't match the checksum pinned in ti-common.sh ($SLINT_DEMO_TI_LAYERSETUP_ARCHIVE_SHA256)." >&2
    echo "Upload this archive and update SLINT_DEMO_TI_LAYERSETUP_ARCHIVE_SHA256 to match." >&2
fi
