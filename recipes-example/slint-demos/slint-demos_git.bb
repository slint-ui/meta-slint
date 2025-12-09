inherit cargo_bin
inherit pkgconfig

SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=ce50ea806a9a1d512d30acab6f99c8a1d511505f"
SRC_URI += "file://0001-WIP-v-1-14-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=e3e11de4e6652abe8c9b2d74b416f33b"

SUMMARY = "Various Rust-based demos of Slint packaged up in /usr/bin"
DESCRIPTION = "This recipe builds various Slint demos such as the energy monitor \
or the printer demo and installs the binaries into /usr/bin."
HOMEPAGE = "https://slint.dev/"
LICENSE = "GPL-3.0-only | Slint-Commercial"

inherit slint_common

PV = "1.14.1+git"

REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append:class-target = " fontconfig libxkbcommon virtual/libgl"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH} ca-certificates-native curl-native"
DEPENDS:append:class-target = " libdrm virtual/egl virtual/libgbm seatd udev libinput"
DEPENDS:append:class-target = " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'x11', 'libxcb', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'wayland', 'wayland', '', d)} \
"
RDEPENDS:${PN} += "xkeyboard-config"

CARGO_DISABLE_BITBAKE_VENDORING = "1"

do_configure[network] = "1"
do_compile[network] = "1"

S = "${WORKDIR}/git"

BBCLASSEXTEND = "native"

EXTRA_CARGO_FLAGS = "-p slint"
CARGO_FEATURES = "slint/backend-linuxkms slint/renderer-skia"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
}
do_compile:append() {
    # Reduce RAM requirements
    export CARGO_PROFILE_RELEASE_LTO=false
    for p in slide_puzzle printerdemo gallery opengl_texture opengl_underlay energy-monitor home-automation; do
        cargo build ${CARGO_BUILD_FLAGS} -p $p
    done
    rm -f "${CARGO_BINDIR}"/*.so
    rm -f "${CARGO_BINDIR}"/*.rlib
}
