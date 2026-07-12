inherit cargo
inherit pkgconfig

# Pinned to a release (not master): the demos get reshuffled on master, e.g. the
# cargo-workspace split that broke the build below. v1.17.1 tag.
SLINT_REV = "cf62c975c311e7036d599ed8ed0b7e6a8386a934"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1;rev=${SLINT_REV}"
SRC_URI += "file://0001-WIP-v-1-14-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=1fa63388f53bdc8a49fc4eef67b55c87"

SUMMARY = "Various Rust-based demos of Slint packaged up in /usr/bin"
DESCRIPTION = "This recipe builds various Slint demos such as the energy monitor \
or the printer demo and installs the binaries into /usr/bin."
HOMEPAGE = "https://slint.dev/"
LICENSE = "GPL-3.0-only | Slint-Commercial"

inherit slint_common
inherit features_check

REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append:class-target = " fontconfig libxkbcommon virtual/libgles2"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH} ca-certificates-native curl-native ninja-native"
DEPENDS:append:class-target = " libdrm virtual/egl virtual/libgbm seatd udev libinput"
DEPENDS:append:class-target = " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'x11', 'libxcb', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'wayland', 'wayland', '', d)} \
"
RDEPENDS:${PN}:class-target += "xkeyboard-config"

CARGO_DISABLE_BITBAKE_VENDORING = "1"
CARGO_BUILD_FLAGS = "-v --target ${RUST_HOST_SYS} ${BUILD_MODE} --manifest-path=${CARGO_MANIFEST_PATH}"

# cargo.bbclass passes features only via PACKAGECONFIG_CONFARGS (empty here);
# So append --features explicitly so machine-specific CARGO_FEATURES overrides take effect.
CARGO_BUILD_FLAGS:append = " ${@'--features ' + ','.join(d.getVar('CARGO_FEATURES').split()) if d.getVar('CARGO_FEATURES') else ''}"

# Build only the demo binaries. A bare `cargo build` compiles the whole default
# workspace -- including slint-viewer (which has its own recipe) and other tools
# -- which is slow and made slint-demos ship /usr/bin/slint-viewer, clashing with
# the slint-viewer package at rootfs time. Scope the build with one -p per demo.
CARGO_BUILD_FLAGS:append = " ${@' '.join('-p ' + p for p in (d.getVar('SLINT_DEMOS') or '').split())}"

do_configure[network] = "1"
do_compile[network] = "1"


BBCLASSEXTEND = "native"

CARGO_FEATURES = "slint/backend-linuxkms slint/renderer-skia"

SLINT_DEMOS = "slide_puzzle printerdemo gallery opengl_texture opengl_underlay energy-monitor home-automation"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
    # Use the git protocol for the crates.io index instead of sparse HTTP
    # so cargo doesn't open hundreds of HTTP/1.1 connections at once
    # (OE-core's curl-native is built without HTTP/2 -- see commit message).
    export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=git
    export CARGO_HTTP_TIMEOUT=120
    export CARGO_NET_RETRY=5
    # Skia + LTO is very RAM-hungry; keep LTO off.
    export CARGO_PROFILE_RELEASE_LTO=false
}
do_compile:append() {
    rm -f "${B}/target/${CARGO_TARGET_SUBDIR}"/*.so
    rm -f "${B}/target/${CARGO_TARGET_SUBDIR}"/*.rlib
}

INSANE_SKIP:${PN} += "buildpaths"
