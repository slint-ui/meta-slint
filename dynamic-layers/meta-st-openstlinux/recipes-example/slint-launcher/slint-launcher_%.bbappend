# The STM32MP15 kits mount the panel rotated, so the launcher (a Slint linuxkms
# app, like the demos) needs the same SLINT_KMS_ROTATION the demo used. Inject it
# per-MACHINE into the launcher's unit -- systemd services don't read
# /etc/environment, so it has to be an explicit Environment= in the unit.
SLINT_KMS_ROTATION ?= "270"
SLINT_KMS_ROTATION:stm32mp2 = "0"

do_install:append() {
  sed -i '/^\[Service\]/a Environment=SLINT_KMS_ROTATION=${SLINT_KMS_ROTATION}' \
    ${D}${systemd_unitdir}/system/slint-launcher.service
}
