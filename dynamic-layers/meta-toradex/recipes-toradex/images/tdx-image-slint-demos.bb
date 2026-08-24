# Slint demo image for Toradex SoMs, booting straight into the Slint launcher on
# KMS/DRM via Slint's linuxkms backend -- no Wayland/X11 compositor, no multimedia
# stack. A lean core-image plus our app and the machine's GPU userspace (the same
# shape as the other demo images).
#
# The image itself is machine-independent; only the GPU userspace is machine
# specific, and that is selected by override (below), so the i.MX95 modules
# (Verdin, SMARC, Aquila) all work. Adding a board needs a build script setting
# MACHINE and a workflow entry; boards on a different GPU stack (the Vivante i.MX8
# modules, the TI-based ones) additionally need their own provider packages here.

SUMMARY = "A minimal image with the Slint demos, running on Toradex SoMs via KMS/DRM (linuxkms)"

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

# GPU userspace. Slint's Skia renderer dlopens EGL/GLES (no ELF NEEDED entry), so
# shlib-deps can't discover them -- and the generic libegl/libgles2 RPROVIDES that
# meta-freescale's GPU recipes emit resolve for the package manager but not in
# bitbake's provider map ("Nothing RPROVIDES libegl"), so name the machine's
# provider packages directly.
#
# Key this on the imxmali override rather than a machine name: meta-freescale adds
# it to MACHINEOVERRIDES for i.MX machines whose GPU provider is mali-imx (see
# IMXGPU_GRAPHICS_PROVIDER:imxmali in imx-base.inc), i.e. the i.MX95 parts on the
# NXP BSP. That covers every Toradex i.MX95 module -- Verdin, SMARC, Aquila -- and
# any future Mali-based i.MX, without listing machines here. (It deliberately does
# not apply to a mainline-BSP build, which renders via mesa/panfrost instead.)
CORE_IMAGE_EXTRA_INSTALL:append:imxmali = " mali-imx-libegl mali-imx-libgles2"

# The same for the Vivante parts (the i.MX8 modules: Verdin/SMARC iMX8M Plus and
# Mini, Apalis iMX8, Colibri iMX8X). meta-freescale sets imxviv for machines whose
# GPU provider is imx-gpu-viv (IMXGPU_GRAPHICS_PROVIDER:imxviv). Note the package
# names differ from Mali's: libegl-imx / libgles2-imx, not <pn>-libegl.
#
# These boards also need the wayland DISTRO_FEATURE, which the build script sets
# -- imx-gpu-viv picks its backend with
#   BACKEND = contains(DISTRO_FEATURES, "wayland", "wayland", "fb")
# and only the wayland build ships the GBM/DRM EGL that linuxkms needs.
CORE_IMAGE_EXTRA_INSTALL:append:imxviv = " libegl-imx libgles2-imx"

# Emit the Toradex Easy Installer (TEZI) bundle -- the standard, guided flashing
# path for Toradex modules: recovery mode + Easy Installer, which provisions the
# on-module eMMC and places the boot container for you. teziimg is Toradex's own
# image type (wired in via their layers for this machine), so a plain core-image
# still emits a valid Easy Installer bundle. (Overriding this to "wic" would
# suppress the TEZI output.) The build script ships it as a single zip: extract it
# onto a USB stick and Easy Installer offers it for install.
IMAGE_FSTYPES = "teziimg"
