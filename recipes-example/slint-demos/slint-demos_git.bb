inherit cargo

SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;rev=master"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=4f9282cc0add078ee5638e65bb55c77c"

SUMMARY = "Slint Demos"
HOMEPAGE = "https://slint-ui.com/"
LICENSE = "GPLv3 | Slint-Commercial"

CARGO_DISABLE_BITBAKE_VENDORING = "1"

do_configure[network] = "1"
do_compile[network] = "1"

S = "${WORKDIR}/git"

BBCLASSEXTEND = "native"

do_compile() {
    export RUST_FONTCONFIG_DLOPEN=on
    oe_cargo_fix_env
    oe_cargo_build -p energy-monitor -p slide_puzzle -p printerdemo -p gallery
}
