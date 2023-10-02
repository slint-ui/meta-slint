inherit cmake
inherit slint

SRC_URI = "git://github.com/slint-ui/slint-cpp-template.git;protocol=https;branch=main;rev=main"

SUMMARY = "Work in progress recipe for Slint Hello World"
HOMEPAGE = "https://github.com/slint-ui/slint"
LICENSE = "GPLv3 | Slint-Commercial"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9e911597e678943cde54111f7518e299"

S = "${WORKDIR}/git"
PV = "slint-hello-world-${SRCPV}"

do_install() {
    install -d ${D}${bindir}
    install -m 755 ${B}/my_application ${D}${bindir}/slint-hello-world
}
