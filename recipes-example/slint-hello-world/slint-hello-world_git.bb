inherit cmake

# Should use the C++ template, but can't because we don't package the slint compiler properly yet.
# So build an interpreter-only C++ example from the Slint repo.
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=master"

SUMMARY = "Slint Hello World"
HOMEPAGE = "https://github.com/slint-ui/slint"
LICENSE = "MIT"

DEPENDS = "slint-cpp"

S = "${WORKDIR}/git"
PV = "slint-hello-world-${SRCPV}"

OECMAKE_SOURCEPATH = "${S}/examples/printerdemo/cpp_interpreted"