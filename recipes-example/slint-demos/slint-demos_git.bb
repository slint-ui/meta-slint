inherit cargo
inherit pkgconfig

SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=master"
SRC_URI += "file://0001-WIP-v-1-14-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=093007ec281bbdeea447b0040b01a74d"

SUMMARY = "Various Rust-based demos of Slint packaged up in /usr/bin"
DESCRIPTION = "This recipe builds various Slint demos such as the energy monitor \
or the printer demo and installs the binaries into /usr/bin."
HOMEPAGE = "https://slint.dev/"
LICENSE = "GPL-3.0-only | Slint-Commercial"

inherit slint_common

PV = "git-${SRCPV}"

REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append:class-target = " fontconfig libxkbcommon virtual/libgl"
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
}
do_compile:append() {
    # Reduce RAM requirements
    export CARGO_PROFILE_RELEASE_LTO=false
    for p in ${SLINT_DEMOS}; do
        cargo build ${CARGO_BUILD_FLAGS} -p $p
    done
    rm -f "${B}/target/${CARGO_TARGET_SUBDIR}"/*.so
    rm -f "${B}/target/${CARGO_TARGET_SUBDIR}"/*.rlib
}
