# Slint demo image for Toradex Verdin SoMs (currently Verdin iMX95), booting
# straight into the Slint launcher on KMS/DRM via Slint's linuxkms backend --
# no Wayland/X11 compositor, no multimedia stack. A lean core-image plus our app
# and the machine's GPU userspace (the same shape as the other demo images).

SUMMARY = "A minimal image with the Slint demos, running on Toradex Verdin via KMS/DRM (linuxkms)"

LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "ssh-server-openssh"

# The launcher is the boot entry point (autostarts via slint-launcher.service)
# and RDEPENDS the demos + viewer it launches, so installing it pulls them in.
# kernel-modules pulls in the loadable display/DRM modules so the KMS path (and
# GPU) come up on a bare image.
CORE_IMAGE_EXTRA_INSTALL += " \
    slint-launcher \
    slint-viewer \
    liberation-fonts \
    kernel-modules \
"

# systemd-networkd + avahi so the board comes up on DHCP and is reachable as
# <hostname>.local.
CORE_IMAGE_EXTRA_INSTALL += " \
    systemd-conf \
    avahi-daemon \
    avahi-utils \
    libnss-mdns \
"

# The i.MX95 has an Arm Mali GPU. Slint's Skia renderer dlopens EGL/GLES (no ELF
# NEEDED entry), so shlib-deps can't discover them -- and the generic
# libegl/libgles2 RPROVIDES that meta-freescale's Mali recipes emit resolve for
# the package manager but not in bitbake's provider map ("Nothing RPROVIDES
# libegl"), so name the machine's Mali provider packages directly.
CORE_IMAGE_EXTRA_INSTALL:append:verdin-imx95 = " mali-imx-libegl mali-imx-libgles2"

# Emit the Toradex Easy Installer (TEZI) bundle -- the standard, guided flashing
# path for Verdin modules: recovery mode + Easy Installer, which provisions the
# on-module eMMC and places the boot container for you. teziimg is Toradex's own
# image type (wired in via their layers for this machine), so a plain core-image
# still emits a valid Easy Installer bundle. (Overriding this to "wic" would
# suppress the TEZI output.) The build script publishes it two ways: a single zip
# to extract onto a USB stick, and a flat set of release assets + image_list.json
# so the demo-images release doubles as an Easy Installer network feed.
IMAGE_FSTYPES = "teziimg"
