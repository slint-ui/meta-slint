inherit systemd

SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "slint-demos.service"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://slint-demos.service file://99-drm-device-unit.rules"
FILES:${PN} += "${systemd_unitdir}/system/slint-demos.service"
FILES:${PN} += "${sysconfdir}/udev/rules.d/99-drm-device-unit.rules"

do_install:append() {
  install -d ${D}/${systemd_unitdir}/system
  install -m 0644 ${UNPACKDIR}/slint-demos.service ${D}/${systemd_unitdir}/system
  # Tag DRM devices for systemd so dev-dri-card0.device exists for the service
  # to order after (the display modules probe late; see the unit).
  install -d ${D}${sysconfdir}/udev/rules.d
  install -m 0644 ${UNPACKDIR}/99-drm-device-unit.rules ${D}${sysconfdir}/udev/rules.d
}

# AM62L has no GPU: run the autostarted demo with Skia's software raster. The
# image is built the same as the GPU boards (Slint's Skia renderer always links
# GL), so software vs GPU is a runtime choice via SLINT_BACKEND.
do_install:append:am62lxx-evm() {
  sed -i '/^\[Service\]/a Environment=SLINT_BACKEND=linuxkms-skia-software' \
    ${D}${systemd_unitdir}/system/slint-demos.service
}
