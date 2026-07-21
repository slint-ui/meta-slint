inherit cargo_bin

SRC_URI = "git://github.com/slint-ui/slint-rust-template.git;protocol=https;branch=main;rev=main"

SUMMARY = "Work in progress recipe for Slint Hello World"
HOMEPAGE = "https://github.com/slint-ui/slint"
LICENSE = "GPL-3.0-only | Slint-Commercial"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9e911597e678943cde54111f7518e299"

DEPENDS:append = " fontconfig"

# scarthgap needs S at the git checkout; newer OE (whinlatter/wrynose) sets it
# itself and rejects the explicit assignment, so only set it on scarthgap.
python () {
    if 'scarthgap' in (d.getVar('LAYERSERIES_CORENAMES') or '').split():
        d.setVar('S', '${WORKDIR}/git')
}
PV = "slint-hello-world-rust-${SRCPV}"

do_compile[network] = "1"
