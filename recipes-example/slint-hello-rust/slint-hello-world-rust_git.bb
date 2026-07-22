inherit cargo_bin

SRC_URI = "git://github.com/slint-ui/slint-rust-template.git;protocol=https;branch=main;rev=main"

SUMMARY = "Work in progress recipe for Slint Hello World"
HOMEPAGE = "https://github.com/slint-ui/slint"
LICENSE = "GPL-3.0-only | Slint-Commercial"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9e911597e678943cde54111f7518e299"

DEPENDS:append = " fontconfig"

# meta-rust-bin's cargo_bin doesn't remap ${WORKDIR} out of rustc's baked-in
# debug paths the way oe-core's rust classes do, so do it here to keep the
# absolute cargo_home paths out of the binary (buildpaths QA).
RUSTFLAGS += "--remap-path-prefix=${WORKDIR}=${TARGET_DBGSRC_DIR}"

# scarthgap needs S at the git checkout; newer OE (whinlatter/wrynose) sets it
# itself and rejects the explicit assignment, so only set it on scarthgap.
python () {
    if 'scarthgap' in (d.getVar('LAYERSERIES_CORENAMES') or '').split():
        d.setVar('S', '${WORKDIR}/git')
}

PV = "slint-hello-world-rust-${SRCPV}"

do_compile[network] = "1"
