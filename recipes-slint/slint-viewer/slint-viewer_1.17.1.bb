inherit cargo_bin
inherit pkgconfig
inherit slint_common

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
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=1fa63388f53bdc8a49fc4eef67b55c87"

# v1.17.1 tag (same revision as slint-cpp_1.17.1)
SLINT_REV = "cf62c975c311e7036d599ed8ed0b7e6a8386a934"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1;rev=${SLINT_REV}"

S = "${WORKDIR}/git"

REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

# Same dependency set as the slint-demos recipe (linuxkms + skia renderer),
# clang-cross is needed for Skia's bindgen. The winit backend and x11/wayland
# libs come in via the slint crate's defaults, pulled by the 'remote' feature.
DEPENDS:append:class-target = " fontconfig libxkbcommon virtual/libgles2"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH} ca-certificates-native curl-native"
DEPENDS:append:class-target = " libdrm virtual/egl virtual/libgbm seatd udev libinput"
DEPENDS:append:class-target = " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'x11', 'libxcb', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'wayland', 'wayland', '', d)} \
"
RDEPENDS:${PN}:class-target += "xkeyboard-config"

# Fetch crate dependencies straight from crates.io rather than pre-vendoring.
CARGO_DISABLE_BITBAKE_VENDORING = "1"
do_configure[network] = "1"
do_compile[network] = "1"

EXTRA_CARGO_FLAGS = "-p slint-viewer --bin slint-viewer"
CARGO_FEATURES = "remote backend-linuxkms renderer-skia"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE

    # Skia + LTO is very RAM-hungry; keep LTO off (as slint-demos does).
    export CARGO_PROFILE_RELEASE_LTO=false

    # Cargo otherwise fans out rustc to all host cores, and Skia's build script
    # reads NUM_JOBS (which cargo derives from this) for its internal ninja.
    # Cap both to keep peak memory bounded and avoid OOM.
    export CARGO_BUILD_JOBS="6"
}
