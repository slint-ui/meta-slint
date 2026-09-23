inherit slint_rust
inherit slint_git_source

SUMMARY = "The Slint viewer, built as the remote viewer"
DESCRIPTION = "slint-viewer is the tool that displays .slint files directly. \
This recipe builds it with the 'remote' cargo feature enabled, so it can act \
as the remote viewer (the --remote flag), receiving a UI over the network and \
rendering it. mDNS service discovery on Linux is provided by the pure-Rust \
mdns-sd crate, so no Avahi dependency is needed. Renderer/backend feature set \
matches the slint-demos recipe (linuxkms + skia)."
HOMEPAGE = "https://slint.dev/"
BUGTRACKER = "https://github.com/slint-ui/slint/issues"
LICENSE = "GPL-3.0-only | Slint-Commercial"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=eddf02df1cb330c56cc727e9e3a379c9"

# v1.18.1 tag (same revision as slint-cpp_1.18.1)
SLINT_REV = "372cf0ee5577c3dfec309a45e7b778ba4e81b734"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1;rev=${SLINT_REV}"

# Same renderer and backend as the slint-demos recipe. The viewer forwards its
# own backend-linuxkms and renderer-skia features to slint, so let slint_rust
# select those, unprefixed. The winit backend and x11/wayland libs come in via
# the slint crate's defaults, pulled by the 'remote' feature.
SLINT_RENDERERS = "skia"
SLINT_BACKENDS = "linuxkms"
SLINT_CARGO_FEATURE_PREFIX = ""

# Build just the viewer binary (its cdylib lib target is Android-only).
EXTRA_CARGO_FLAGS = "-p slint-viewer --bin slint-viewer"
CARGO_FEATURES = "remote"
