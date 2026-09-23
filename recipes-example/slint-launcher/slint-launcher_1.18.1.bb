# Pinned to the same revision as the slint-demos and slint-viewer recipes
# (v1.18.1), which carries demos/launcher.
SLINT_REV = "372cf0ee5577c3dfec309a45e7b778ba4e81b734"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1;rev=${SLINT_REV}"
SRC_URI += "file://slint-launcher.service"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=eddf02df1cb330c56cc727e9e3a379c9"

SUMMARY = "A launcher menu to discover and run the installed Slint demos"
DESCRIPTION = "Builds the Slint demo launcher (demos/launcher): a menu that scans \
PATH for the installed Slint demo binaries, lists them, and launches the selected \
one (via exec on LinuxKMS), plus an entry to start the remote slint-viewer."
HOMEPAGE = "https://slint.dev/"
LICENSE = "GPL-3.0-only | Slint-Commercial"

inherit slint_rust
inherit slint_git_source

# The launcher discovers and execs the demo binaries on PATH and offers a
# "remote viewer" entry, so both must be installed alongside it.
RDEPENDS:${PN}:class-target += "slint-demos slint-viewer"

# The demos live in their own cargo workspace (demos/), separate from the repo
# root -- so build the launcher package from that manifest, not the root (a plain
# "-p launcher" from the root workspace doesn't resolve). The produced
# binary is slint-demo-launcher. Build for the embedded target with the LinuxKMS
# backend + libinput and no windowing default (--no-default-features drops
# slint/default), and the Skia renderer (renderer-skia) to match the demos --
# enabling that feature makes Skia the default renderer, so no runtime override
# is needed.
CARGO_MANIFEST_PATH = "${S}/demos/Cargo.toml"
EXTRA_CARGO_FLAGS = "--no-default-features -p launcher"

# The launcher forwards its own backend-linuxkms and renderer-skia features to
# slint, so let slint_rust select those, unprefixed.
SLINT_RENDERERS = "skia"
SLINT_BACKENDS = "linuxkms"
SLINT_CARGO_FEATURE_PREFIX = ""

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
