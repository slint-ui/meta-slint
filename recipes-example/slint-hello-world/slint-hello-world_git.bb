inherit cmake

# Should use the C++ template, but can't because we don't package the slint compiler properly yet.
# So build an interpreter-only C++ example from the Slint repo.
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=master"

SUMMARY = "Work in progress recipe for Slint Hello World"
HOMEPAGE = "https://github.com/slint-ui/slint"
LICENSE = "GPLv3 | Slint-Commercial"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=4f9282cc0add078ee5638e65bb55c77c"

DEPENDS = "slint-cpp"

S = "${WORKDIR}/git"
PV = "slint-hello-world-${SRCPV}"


OECMAKE_SOURCEPATH = "${S}/examples/printerdemo/cpp_interpreted"
