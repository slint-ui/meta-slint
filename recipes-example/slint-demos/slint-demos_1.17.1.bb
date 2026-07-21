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

REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append:class-target = " fontconfig libxkbcommon virtual/libgles2"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH} ca-certificates-native curl-native"
DEPENDS:append:class-target = " libdrm virtual/egl virtual/libgbm seatd udev libinput"
DEPENDS:append:class-target = " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'x11', 'libxcb', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'wayland', 'wayland', '', d)} \
"
RDEPENDS:${PN}:class-target += "xkeyboard-config"

CARGO_DISABLE_BITBAKE_VENDORING = "1"

do_configure[network] = "1"
do_compile[network] = "1"

BBCLASSEXTEND = "native"

EXTRA_CARGO_FLAGS = "-p slint"
CARGO_FEATURES = "slint/backend-linuxkms slint/renderer-skia"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
}
do_compile:append() {
    export CARGO_PROFILE_RELEASE_LTO=false   # reduce RAM
    # Build each demo binary; at v1.17.1 they're all members of the root workspace.
    for p in slide_puzzle printerdemo gallery opengl_texture opengl_underlay energy-monitor home-automation; do
        cargo build ${CARGO_BUILD_FLAGS} -p $p
    done
    rm -f "${CARGO_BINDIR}"/*.so
    rm -f "${CARGO_BINDIR}"/*.rlib
}
