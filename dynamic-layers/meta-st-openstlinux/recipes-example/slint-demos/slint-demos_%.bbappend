# The launcher is now the boot entry point (see the slint-launcher bbappend), so
# the demo no longer autostarts here. But the touch calibration matrix (the panel
# is mounted rotated on the STM32MP15 kits) is needed regardless of which app
# runs, so keep shipping it via slint-demos, which stays in the image as one of
# the binaries the launcher runs.
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://touch_rotation.rules"
FILES:${PN} += "${sysconfdir}/udev/rules.d/touch_rotation.rules"

do_install:append() {
  install -d ${D}${sysconfdir}/udev/rules.d
  install -p -m 0644 ${WORKDIR}/touch_rotation.rules ${D}${sysconfdir}/udev/rules.d/
}
