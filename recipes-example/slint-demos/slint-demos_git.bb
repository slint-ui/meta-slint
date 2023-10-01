inherit cargo

SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=master"
SRC_URI += "file://0001-WIP-v1-2-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=c12ffea0eacb376c3ba8c0601fe78d5d"

SUMMARY = "Various Rust-based demos of Slint packaged up in /usr/bin"
DESCRIPTION = "This recipe builds various Slint demos such as the energy monitor \
or the printer demo and installs the binaries into /usr/bin."
HOMEPAGE = "https://slint-ui.com/"
LICENSE = "GPLv3 | Slint-Commercial"

inherit slint_common

CARGO_DISABLE_BITBAKE_VENDORING = "1"

do_configure[network] = "1"
do_compile[network] = "1"

S = "${WORKDIR}/git"

BBCLASSEXTEND = "native"

do_compile() {
    oe_cargo_build --features slint/renderer-skia -p energy-monitor -p slide_puzzle -p printerdemo -p gallery -p opengl_texture -p opengl_underlay
}
