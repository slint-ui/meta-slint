inherit cargo
inherit pkgconfig

# The launcher (demos/launcher) only exists on master; it is not in the release
# the slint-demos recipe is pinned to (release/1, v1.17.1). Track it separately.
# Pinned to the commit that merged slint-ui/slint#12530 (the launcher) into master.
SLINT_REV = "7379c4a01579d6614b7d38b564f9430f4e78a960"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=${SLINT_REV}"
SRC_URI += "file://slint-launcher.service"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=1fa63388f53bdc8a49fc4eef67b55c87"

SUMMARY = "A launcher menu to discover and run the installed Slint demos"
DESCRIPTION = "Builds the Slint demo launcher (demos/launcher): a menu that scans \
PATH for the installed Slint demo binaries, lists them, and launches the selected \
one (via exec on LinuxKMS), plus an entry to start the remote slint-viewer."
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

# The launcher discovers and execs the demo binaries on PATH and offers a
# "remote viewer" entry, so both must be installed alongside it.
RDEPENDS:${PN}:class-target += "slint-demos slint-viewer"

# Fetch crate dependencies straight from crates.io rather than pre-vendoring.
CARGO_DISABLE_BITBAKE_VENDORING = "1"

# On master the demos live in their own cargo workspace (demos/), separate from
# the repo root -- so build the launcher package from that manifest, not the root
# (a plain "-p launcher" from the root workspace doesn't resolve). The produced
# binary is slint-demo-launcher. Build for the embedded target with the LinuxKMS
# backend + libinput and no windowing default (--no-default-features drops
# slint/default), and the Skia renderer (renderer-skia) to match the demos --
# enabling that feature makes Skia the default renderer, so no runtime override
# is needed.
CARGO_MANIFEST_PATH = "${S}/demos/Cargo.toml"
CARGO_BUILD_FLAGS = "-v --target ${RUST_HOST_SYS} ${BUILD_MODE} --manifest-path=${CARGO_MANIFEST_PATH} --no-default-features -p launcher"

# cargo.bbclass passes features only via PACKAGECONFIG_CONFARGS (empty here);
# So append --features explicitly so machine-specific CARGO_FEATURES overrides take effect.
CARGO_BUILD_FLAGS:append = " ${@'--features ' + ','.join(d.getVar('CARGO_FEATURES').split()) if d.getVar('CARGO_FEATURES') else ''}"

CARGO_FEATURES = "backend-linuxkms renderer-skia"

do_configure[network] = "1"
do_compile[network] = "1"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
    # Use the git protocol for the crates.io index instead of sparse HTTP
    # so cargo doesn't open hundreds of HTTP/1.1 connections at once
    # (OE-core's curl-native is built without HTTP/2).
    export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=git
    export CARGO_HTTP_TIMEOUT=120
    export CARGO_NET_RETRY=5
    # Skia + LTO is very RAM-hungry; keep LTO off (as slint-demos does).
    export CARGO_PROFILE_RELEASE_LTO=false
}
do_compile:append() {
    rm -f "${B}/target/${CARGO_TARGET_SUBDIR}"/*.so
    rm -f "${B}/target/${CARGO_TARGET_SUBDIR}"/*.rlib
}

INSANE_SKIP:${PN} += "buildpaths"

# The launcher is the boot entry point: autostart it, and it launches the demos.
inherit systemd
SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "slint-launcher.service"
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
FILES:${PN} += "${systemd_unitdir}/system/slint-launcher.service"

do_install:append() {
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/slint-launcher.service ${D}${systemd_unitdir}/system
}
