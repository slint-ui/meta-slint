inherit cargo_bin
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

# Build only the demo binaries. A bare `cargo build` compiles the whole default
# workspace -- including slint-viewer (which has its own recipe) and other tools
# -- which is slow and made slint-demos ship /usr/bin/slint-viewer, clashing with
# the slint-viewer package at rootfs time. Scope the build with one -p per demo.
# cargo_bin turns CARGO_FEATURES into --features on its own.
EXTRA_CARGO_FLAGS = "${@' '.join('-p ' + p for p in (d.getVar('SLINT_DEMOS') or '').split())}"

do_configure[network] = "1"
do_compile[network] = "1"


BBCLASSEXTEND = "native"

CARGO_FEATURES = "slint/backend-linuxkms slint/renderer-skia"

SLINT_DEMOS = "slide_puzzle printerdemo gallery opengl_texture opengl_underlay energy-monitor home-automation"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
    # Skia + LTO is very RAM-hungry; keep LTO off.
    export CARGO_PROFILE_RELEASE_LTO=false
}
do_compile:append() {
    # cargo_bin_do_install ships every .so/.rlib next to the demo binaries; drop
    # them so the demos package carries just the executables.
    rm -f "${CARGO_BINDIR}"/*.so
    rm -f "${CARGO_BINDIR}"/*.rlib
}

# The demo binaries carry absolute build paths that the Rust --remap-path-prefix
# cannot rewrite: the slint compiler bakes the gettext translation dir
# (examples/*/lang) in as a string literal, and the vendored aws-lc-sys C crate
# bakes its source paths into debug info. These are example binaries, so accept
# the paths rather than chase every embedder. (slint-cpp/viewer/launcher are fully
# remapped and keep the check.)
INSANE_SKIP:${PN} += "buildpaths"
INSANE_SKIP:${PN}-dbg += "buildpaths"
INSANE_SKIP:${PN}-src += "buildpaths"
