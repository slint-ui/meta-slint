inherit systemd

SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "slint-demos.service"

# Boot demo + screen rotation, per MACHINE. Defaults suit the STM32MP15 kits.
SLINT_DEMO_BINARY ?= "energy-monitor"
SLINT_DEMO_BINARY:stm32mp2 = "home-automation"
SLINT_KMS_ROTATION ?= "270"
SLINT_KMS_ROTATION:stm32mp2 = "0"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://slint-demos.service file://touch_rotation.rules"
FILES:${PN} += "${systemd_unitdir}/system/slint-demos.service"
FILES:${PN} += "${sysconfdir}/udev/rules.d/touch_rotation.rules"

do_install:append() {
  install -d ${D}/${systemd_unitdir}/system
  install -m 0644 ${WORKDIR}/slint-demos.service ${D}/${systemd_unitdir}/system
  # Substitute the per-MACHINE demo binary and rotation into the unit.
  sed -i \
    -e 's/@SLINT_DEMO_BINARY@/${SLINT_DEMO_BINARY}/g' \
    -e 's/@SLINT_KMS_ROTATION@/${SLINT_KMS_ROTATION}/g' \
    ${D}/${systemd_unitdir}/system/slint-demos.service
  install -d ${D}${sysconfdir}/udev/rules.d
  install -p -m 0644 ${WORKDIR}/touch_rotation.rules ${D}${sysconfdir}/udev/rules.d/
}
