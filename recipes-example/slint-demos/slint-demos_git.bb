inherit cargo_bin
inherit pkgconfig

SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=0301c9d7d8b9bb6f5a90d0068503bce4f379b065"
SRC_URI += "file://0001-WIP-v-1-6-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=fce682d891cef27e78643d58a1c80149"

SUMMARY = "Various Rust-based demos of Slint packaged up in /usr/bin"
DESCRIPTION = "This recipe builds various Slint demos such as the energy monitor \
or the printer demo and installs the binaries into /usr/bin."
HOMEPAGE = "https://slint.dev/"
LICENSE = "GPLv3 | Slint-Commercial"

inherit slint_common

PV = "1.12.0+git"

REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append:class-target = " fontconfig libxkbcommon virtual/libgl"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH} ca-certificates-native curl-native"
DEPENDS:append:class-target = " libdrm virtual/egl virtual/libgbm seatd udev libinput"
DEPENDS:append:class-target = " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'x11', 'libxcb', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'wayland', 'wayland', '', d)} \
"

CARGO_DISABLE_BITBAKE_VENDORING = "1"

do_configure[network] = "1"
do_compile[network] = "1"

S = "${WORKDIR}/git"

BBCLASSEXTEND = "native"

do_configure:append() {
    # Work around current half not cross-compiling well
    (cd ${S} && cargo update -p half --precise 2.2.1)
}

EXTRA_CARGO_FLAGS = "-p slide_puzzle"
CARGO_FEATURES = "slint/backend-linuxkms slint/renderer-skia"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
}
do_compile:append() {
    for p in printerdemo gallery opengl_texture opengl_underlay energy-monitor; do
        cargo build ${CARGO_BUILD_FLAGS} -p $p
    done
    rm -f "${CARGO_BINDIR}"/*.so
    rm -f "${CARGO_BINDIR}"/*.rlib
}
