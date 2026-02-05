inherit cargo_bin

SRC_URI = "git://github.com/slint-ui/slint-rust-template.git;protocol=https;branch=main;rev=main"

SUMMARY = "Work in progress recipe for Slint Hello World"
HOMEPAGE = "https://github.com/slint-ui/slint"
LICENSE = "GPL-3.0-only | Slint-Commercial"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9e911597e678943cde54111f7518e299"

DEPENDS:append = " fontconfig"

S = "${WORKDIR}/git"
PV = "slint-hello-world-rust-${SRCPV}"

do_compile[network] = "1"
