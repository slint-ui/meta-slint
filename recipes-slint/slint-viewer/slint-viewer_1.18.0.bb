inherit cargo_bin
inherit pkgconfig
inherit slint_common
inherit features_check

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

# v1.18.0 tag (same revision as slint-cpp_1.18.0)
SLINT_REV = "bd20dab8529add087b5cbc81aec70bf30861ae4c"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1;rev=${SLINT_REV}"

REQUIRED_DISTRO_FEATURES:append = ""
REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

# Same dependency set as the slint-demos recipe (linuxkms + skia renderer),
# clang-cross is needed for Skia's bindgen. The winit backend and x11/wayland
# libs come in via the slint crate's defaults, pulled by the 'remote' feature.
DEPENDS:append:class-target = " fontconfig libxkbcommon virtual/libgles2"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH} ca-certificates-native curl-native ninja-native"
DEPENDS:append:class-target = " libdrm virtual/egl virtual/libgbm seatd udev libinput"
DEPENDS:append:class-target = " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'x11', 'libxcb', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'wayland', 'wayland', '', d)} \
"
RDEPENDS:${PN}:class-target += "xkeyboard-config"

# Fetch crate dependencies straight from crates.io rather than pre-vendoring.
CARGO_DISABLE_BITBAKE_VENDORING = "1"

# Build just the viewer binary (its cdylib lib target is Android-only). cargo_bin
# turns CARGO_FEATURES into --features on its own.
EXTRA_CARGO_FLAGS = "-p slint-viewer --bin slint-viewer"
CARGO_FEATURES = "remote backend-linuxkms renderer-skia"

do_configure[network] = "1"
do_compile[network] = "1"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE

    # Skia + LTO is very RAM-hungry; keep LTO off (as slint-demos does). The job
    # count is bounded globally via CARGO_BUILD_JOBS (see common.sh).
    export CARGO_PROFILE_RELEASE_LTO=false
}
