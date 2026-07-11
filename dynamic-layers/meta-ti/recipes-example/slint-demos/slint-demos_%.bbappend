inherit systemd

SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "slint-demos.service"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://slint-demos.service"
FILES:${PN} += "${systemd_unitdir}/system/slint-demos.service"

do_install:append() {
  install -d ${D}/${systemd_unitdir}/system
  install -m 0644 ${UNPACKDIR}/slint-demos.service ${D}/${systemd_unitdir}/system
}

# AM62L has no GPU: run the autostarted demo with Skia's software raster. The
# image is built the same as the GPU boards (Slint's Skia renderer always links
# GL), so software vs GPU is a runtime choice via SLINT_BACKEND.
do_install:append:am62lxx-evm() {
  sed -i '/^\[Service\]/a Environment=SLINT_BACKEND=linuxkms-skia-software' \
    ${D}${systemd_unitdir}/system/slint-demos.service
}
