SUMMARY = "Return to the Slint demo launcher with a four-finger swipe down from the top edge"
DESCRIPTION = "A small daemon that watches the touchscreens and, on a four-finger \
swipe down from the top edge of the screen, restarts slint-launcher.service, \
replacing the demo that the Slint demo launcher exec()ed into with the launcher \
menu."
HOMEPAGE = "https://slint.dev/"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://Cargo.toml \
    file://Cargo.lock \
    file://src/main.rs \
    file://slint-launcher-gesture.service \
"

inherit cargo_bin
# Not just for pkgconfig-native (which cargo_bin adds): on walnascar+ the class
# also exports the PKG_CONFIG_* variables that make the udev crate's
# libudev-sys find libudev in the target sysroot.
inherit pkgconfig

# The input crate links libinput, and its udev support libudev.
DEPENDS += "libinput udev"

# File-only recipe: the sources land in UNPACKDIR on the releases that define it
# (styhead and later) and in WORKDIR on older ones.
S = "${@d.getVar('UNPACKDIR') or d.getVar('WORKDIR')}"

# cargo fetches the crates while building, the versions Cargo.lock pins.
do_compile[network] = "1"
EXTRA_CARGO_FLAGS = "--locked"

# Keep the crates' build paths out of the binary, as slint_skia does.
RUSTFLAGS += "--remap-path-prefix=${WORKDIR}=${TARGET_DBGSRC_DIR}"

inherit systemd
SYSTEMD_SERVICE:${PN} = "slint-launcher-gesture.service"

do_install:append() {
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${S}/slint-launcher-gesture.service ${D}${systemd_unitdir}/system
}
