# TI-specific tweaks to the launcher's autostart unit.
#
# The launcher is the boot entry point on the TI boards (the base recipe
# autostarts slint-launcher.service). Two things need adding on TI:
#
#  1. DRM-device ordering. tidss (the display controller) and its HDMI bridge
#     (sii902x) are loadable modules that only probe a few seconds into boot, so
#     /dev/dri/card0 doesn't exist yet when systemd would otherwise start the
#     launcher -- it would fail to open the DRM device and leave the screen dark.
#     Order after the card's device unit (which systemd materialises once the DRM
#     node is tagged for it -- see 99-drm-device-unit.rules); seatd, if present,
#     brokers DRM/input access. The base unit's Restart=always then covers any
#     residual early-probe race.
#
#  2. AM62L software rendering (see below).
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://slint-launcher-drm.conf file://99-drm-device-unit.rules"

FILES:${PN} += "${systemd_unitdir}/system/slint-launcher.service.d/10-drm-device.conf"
FILES:${PN} += "${sysconfdir}/udev/rules.d/99-drm-device-unit.rules"

do_install:append() {
  install -d ${D}${systemd_unitdir}/system/slint-launcher.service.d
  install -m 0644 ${UNPACKDIR}/slint-launcher-drm.conf \
    ${D}${systemd_unitdir}/system/slint-launcher.service.d/10-drm-device.conf
  # Tag DRM devices for systemd so dev-dri-card0.device exists for the launcher
  # unit to order after (the display modules probe late; see the drop-in).
  install -d ${D}${sysconfdir}/udev/rules.d
  install -m 0644 ${UNPACKDIR}/99-drm-device-unit.rules ${D}${sysconfdir}/udev/rules.d
}

# AM62L has no GPU: run the launcher (and the demos it exec()s into, which
# inherit its environment) with Skia's software raster. systemd units don't read
# /etc/environment, so set it on the unit via the same drop-in.
do_install:append:am62lxx-evm() {
  cat >> ${D}${systemd_unitdir}/system/slint-launcher.service.d/10-drm-device.conf <<'EOF'

[Service]
Environment=SLINT_BACKEND=linuxkms-skia-software
EOF
}
