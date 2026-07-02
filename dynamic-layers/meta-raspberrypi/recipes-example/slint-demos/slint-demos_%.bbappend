inherit systemd

SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "slint-demos.service"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://slint-demos.service"
FILES:${PN} += "${systemd_unitdir}/system/slint-demos.service"

do_install:append() {
  install -d ${D}/${systemd_unitdir}/system
  install -m 0644 ${WORKDIR}/slint-demos.service ${D}/${systemd_unitdir}/system
}
