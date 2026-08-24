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
#
# This layer is keyed on the meta-ti-bsp collection, but some non-TI BSPs bundle
# meta-ti too (e.g. Toradex, for their Verdin AM62 modules), so this bbappend is
# also parsed in those builds. Gate the drop-in install on the TI display
# machines so it never lands on an unrelated board (and so its files/paths are
# only referenced where they apply).
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://slint-launcher-drm.conf file://99-drm-device-unit.rules"

FILES:${PN} += "${systemd_unitdir}/system/slint-launcher.service.d/10-drm-device.conf"
FILES:${PN} += "${sysconfdir}/udev/rules.d/99-drm-device-unit.rules"

# COMPATIBLE_PACKDIR (from cargo_bin) is where file:// SRC_URI entries land:
# UNPACKDIR on walnascar+ (whinlatter/wrynose), WORKDIR on scarthgap.
do_install:append:am62pxx-evm() {
  install -d ${D}${systemd_unitdir}/system/slint-launcher.service.d
  install -m 0644 ${COMPATIBLE_PACKDIR}/slint-launcher-drm.conf \
    ${D}${systemd_unitdir}/system/slint-launcher.service.d/10-drm-device.conf
  install -d ${D}${sysconfdir}/udev/rules.d
  install -m 0644 ${COMPATIBLE_PACKDIR}/99-drm-device-unit.rules ${D}${sysconfdir}/udev/rules.d
}

# AM62L has no GPU: install the same DRM drop-in and, on top, run the launcher
# (and the demos it exec()s into, which inherit its environment) with Skia's
# software raster. systemd units don't read /etc/environment, so set it on the
# unit via the same drop-in.
do_install:append:am62lxx-evm() {
  install -d ${D}${systemd_unitdir}/system/slint-launcher.service.d
  install -m 0644 ${COMPATIBLE_PACKDIR}/slint-launcher-drm.conf \
    ${D}${systemd_unitdir}/system/slint-launcher.service.d/10-drm-device.conf
  install -d ${D}${sysconfdir}/udev/rules.d
  install -m 0644 ${COMPATIBLE_PACKDIR}/99-drm-device-unit.rules ${D}${sysconfdir}/udev/rules.d
  cat >> ${D}${systemd_unitdir}/system/slint-launcher.service.d/10-drm-device.conf <<'EOF'

[Service]
Environment=SLINT_BACKEND=linuxkms-skia-software
EOF
}
