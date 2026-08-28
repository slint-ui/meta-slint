#!/bin/bash

# Validate a version bump without building anything.
#
# Sets up the same layer stack as ci.sh (poky-wrynose + meta-clang +
# meta-rust-bin + this layer, via ci_setup.sh), pins the new version, and then
# runs two cheap gates:
#
#   bitbake -p                parses every recipe in every layer, so a syntax
#                             error or a bad require/include in the new recipes
#                             fails here rather than in a 6-hour build
#
#   bitbake -c populate_lic   runs do_fetch -> do_unpack -> do_patch ->
#                             do_populate_lic for the three bumped recipes. That
#                             applies the gettext patches through Yocto's own
#                             patch machinery and verifies LIC_FILES_CHKSUM
#                             against the real LICENSE.md -- the two things a
#                             version bump actually gets wrong -- while
#                             compiling nothing.
#
# Run from the directory that contains the meta-slint checkout, like ci.sh:
#     meta-slint/scripts/validate-slint-version.sh 1.18.0

set -ex

version="$1"
if [ -z "$version" ]; then
    echo "usage: $0 <version>" >&2
    exit 1
fi

here="$(cd "$(dirname "$0")" && pwd)"

"$here/ci_setup.sh"

cd bitbake-builds/poky-wrynose
. build/init-build-env

# Without this bitbake would pick the _git recipe, which tracks master and is not
# what we just bumped.
cat >> conf/local.conf <<EOF
PREFERRED_VERSION_slint-cpp = "$version"
PREFERRED_VERSION_slint-cpp-native = "$version"
PREFERRED_VERSION_nativesdk-slint-cpp = "$version"
EOF

bitbake -p

bitbake -c populate_lic slint-cpp slint-demos slint-viewer slint-launcher

echo "slint $version: recipes parse, patches apply, license checksums match"
