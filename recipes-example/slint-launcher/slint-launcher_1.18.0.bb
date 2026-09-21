inherit cargo_bin
inherit pkgconfig

# Pinned to the same revision as the slint-demos and slint-viewer recipes
# (v1.18.0), which carries demos/launcher.
SLINT_REV = "bd20dab8529add087b5cbc81aec70bf30861ae4c"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1;rev=${SLINT_REV}"
SRC_URI += "file://slint-launcher.service"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=eddf02df1cb330c56cc727e9e3a379c9"

SUMMARY = "A launcher menu to discover and run the installed Slint demos"
DESCRIPTION = "Builds the Slint demo launcher (demos/launcher): a menu that scans \
PATH for the installed Slint demo binaries, lists them, and launches the selected \
one (via exec on LinuxKMS), plus an entry to start the remote slint-viewer."
HOMEPAGE = "https://slint.dev/"
LICENSE = "GPL-3.0-only | Slint-Commercial"

inherit slint_common
inherit features_check

REQUIRED_DISTRO_FEATURES:append = ""
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

# The demos live in their own cargo workspace (demos/), separate from the repo
# root -- so build the launcher package from that manifest, not the root (a plain
# "-p launcher" from the root workspace doesn't resolve). The produced
# binary is slint-demo-launcher. Build for the embedded target with the LinuxKMS
# backend + libinput and no windowing default (--no-default-features drops
# slint/default), and the Skia renderer (renderer-skia) to match the demos --
# enabling that feature makes Skia the default renderer, so no runtime override
# is needed.
CARGO_MANIFEST_PATH = "${S}/demos/Cargo.toml"

# cargo_bin turns CARGO_FEATURES into --features on its own.
EXTRA_CARGO_FLAGS = "--no-default-features -p launcher"
CARGO_FEATURES = "backend-linuxkms renderer-skia"

do_configure[network] = "1"
do_compile[network] = "1"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
    # Skia + LTO is very RAM-hungry; keep LTO off (as slint-demos does).
    export CARGO_PROFILE_RELEASE_LTO=false
}
do_compile:append() {
    # cargo_bin_do_install ships every .so/.rlib next to the launcher binary; drop
    # them so the package carries just the executable.
    rm -f "${CARGO_BINDIR}"/*.so
    rm -f "${CARGO_BINDIR}"/*.rlib
}

# The launcher is the boot entry point: autostart it, and it launches the demos.
inherit systemd
SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "slint-launcher.service"
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
FILES:${PN} += "${systemd_unitdir}/system/slint-launcher.service"

do_install:append() {
    install -d ${D}${systemd_unitdir}/system
    # COMPATIBLE_PACKDIR (from cargo_bin) is where file:// SRC_URI entries land:
    # UNPACKDIR on walnascar+ (whinlatter/wrynose), WORKDIR on scarthgap.
    install -m 0644 ${COMPATIBLE_PACKDIR}/slint-launcher.service ${D}${systemd_unitdir}/system
}
