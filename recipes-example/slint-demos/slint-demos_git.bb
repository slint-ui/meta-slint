inherit cargo

SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=master"
SRC_URI += "file://0001-WIP-v1-2-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=0cfef883ea34026eab43837344667cfe"

SUMMARY = "Various Rust-based demos of Slint packaged up in /usr/bin"
DESCRIPTION = "This recipe builds various Slint demos such as the energy monitor \
or the printer demo and installs the binaries into /usr/bin."
HOMEPAGE = "https://slint.dev/"
LICENSE = "GPLv3 | Slint-Commercial"

inherit slint_common

REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append:class-target = " fontconfig virtual/libgl"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH} ca-certificates-native"
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

do_compile() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
    oe_cargo_build --features slint/renderer-skia,slint/backend-linuxkms -p energy-monitor -p slide_puzzle -p printerdemo -p gallery -p opengl_texture -p opengl_underlay
}
