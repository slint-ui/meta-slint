inherit cargo_bin
inherit pkgconfig

SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=644e15dee19fb1a72975c81e62892b9251a1111a"
SRC_URI += "file://0001-WIP-v1-2-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=fce682d891cef27e78643d58a1c80149"

SUMMARY = "Various Rust-based demos of Slint packaged up in /usr/bin"
DESCRIPTION = "This recipe builds various Slint demos such as the energy monitor \
or the printer demo and installs the binaries into /usr/bin."
HOMEPAGE = "https://slint.dev/"
LICENSE = "GPLv3 | Slint-Commercial"

inherit slint_common

PV = "1.6.0+git"

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

EXTRA_CARGO_FLAGS = "-p slide_puzzle -p printerdemo -p gallery -p opengl_texture -p opengl_underlay -p energy-monitor"
CARGO_FEATURES = "slint/backend-linuxkms slint/renderer-skia"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
}
do_compile:append() {
    rm -f "${CARGO_BINDIR}"/*.so
    rm -f "${CARGO_BINDIR}"/*.rlib
}
