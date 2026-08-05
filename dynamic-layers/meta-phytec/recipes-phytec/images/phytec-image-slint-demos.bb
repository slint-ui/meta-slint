# Slint demo image for PHYTEC i.MX boards, rendered fullscreen on the display via
# KMS/DRM (Slint's linuxkms backend) -- the Slint analog of PHYTEC's Qt eglfs
# demo image. Like meta-qt5-phytec's phytec-qt5demo-image, we build on PHYTEC's
# curated headless base (which brings the machine-appropriate kernel + display
# modules, firmware and init for the ampliphy distro) rather than bare
# core-image, and add only our app + the GPU userspace on top. "headless" is the
# right base for a single-app KMS image: no weston/X compositor, output goes
# straight to the display controller.
require recipes-images/images/phytec-headless-image.bb

SUMMARY = "A minimal image with the Slint demos, running on PHYTEC i.MX via the linuxkms (eglfs-style) backend"

LICENSE = "MIT"

# Don't add an SSH server here: PHYTEC's headless base already pulls OpenSSH in
# (via packagegroup-userland). Adding ssh-server-dropbear would install dropbear
# too, and dropbear and openssh conflict (both provide the SSH server), failing
# do_rootfs. We keep the base image's OpenSSH.

# The launcher is the boot entry point (autostarts via slint-launcher.service)
# and RDEPENDS the demos + viewer it launches, so installing it pulls them in.
# The i.MX 8M Mini has a Vivante GC NanoUltra GPU; Slint's Skia renderer loads
# EGL/GLES via dlopen (no ELF NEEDED entry), so -- unlike Qt's eglfs, whose
# virtual/egl dependency drags the GPU userspace in -- nothing pulls it in
# implicitly. Install NXP's Vivante graphics stack (imx-gpu-viv EGL/GLES/GBM)
# explicitly via packagegroup-fsl-tools-gpu.
IMAGE_INSTALL += " \
    slint-launcher \
    slint-viewer \
    liberation-fonts \
    packagegroup-fsl-tools-gpu \
"

# systemd-networkd + avahi so the board comes up on DHCP and is reachable as
# <hostname>.local (the ampliphy distro runs systemd).
IMAGE_INSTALL += " \
    systemd-conf \
    avahi-daemon \
    avahi-utils \
    libnss-mdns \
"

# Raw SD-card image; the build script relabels it to <device>-slint-demo.img and
# zips it. The PHYTEC machine provides the WKS (boot partition + ext4 rootfs).
IMAGE_FSTYPES = "wic"
