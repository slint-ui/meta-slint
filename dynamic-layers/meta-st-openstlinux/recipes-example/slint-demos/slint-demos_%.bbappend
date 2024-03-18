inherit systemd

SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "slint-demos.service"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://slint-demos.service file://touch_rotation.rules"
FILES:${PN} += "${systemd_unitdir}/system/slint-demos.service"
FILES:${PN} += "${sysconfdir}/udev/rules.d/touch_rotation.rules"

do_install:append() {
  install -d ${D}/${systemd_unitdir}/system
  install -m 0644 ${WORKDIR}/slint-demos.service ${D}/${systemd_unitdir}/system
  install -d ${D}${sysconfdir}/udev/rules.d
  install -p -m 0644 ${WORKDIR}/touch_rotation.rules ${D}${sysconfdir}/udev/rules.d/
}
