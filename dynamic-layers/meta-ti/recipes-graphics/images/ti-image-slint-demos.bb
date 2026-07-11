SUMMARY = "A minimal image with the Slint demos, running on TI Sitara via KMS/DRM"

LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "ssh-server-dropbear"

CORE_IMAGE_BASE_INSTALL += " \
    slint-demos \
    slint-viewer \
    liberation-fonts \
"

# systemd-networkd + avahi so the board comes up on DHCP and is reachable as
# <hostname>.local (the image runs systemd; see INIT_MANAGER in the build script).
CORE_IMAGE_BASE_INSTALL += " \
    systemd-conf \
    avahi-daemon \
    avahi-utils \
    libnss-mdns \
"

# The KMS/DRM display path. TI's kernel builds the display-subsystem driver
# (tidss) and the on-board HDMI bridge (sii902x on the SK boards) as loadable
# modules, but the machine config doesn't mark them essential -- so a bare
# core-image ships without them and /dev/dri ends up with only a render node and
# no HDMI connector, leaving the screen dark. Pull in the full built module set
# so tidss and its bridge/connector chain land in the image. Both boards need
# this: the demo scans out via tidss whether it renders on the GPU (AM62Px) or
# in software (AM62L).
CORE_IMAGE_BASE_INSTALL += " kernel-modules"

# AM62Px has the PowerVR AXE-1-16M GPU. A bare core-image pulls in no graphics
# stack, and Slint's Skia renderer loads EGL/GLES via dlopen (there's no ELF
# NEEDED entry), so nothing drags them in implicitly -- the pvrsrvkm kernel
# module and libEGL/libGLESv2 end up absent at runtime. Install just the minimal
# GPU runtime the demo needs: Mesa's EGL/GLES/GBM via the PowerVR Gallium driver
# (mesa-megadriver RRECOMMENDS the pvrsrvkm ti-img-rogue-driver) and the Rogue
# DDK user libraries, which RDEPEND that kernel module and its firmware. We skip
# the arago-graphics packagegroup on purpose: it drags in glmark2/kmscube, and
# glmark2 wants wayland-protocols -- but this is a KMS/DRM image with no
# compositor, so wayland stays out of the target. (AM62L has no GPU and renders
# in software, so it gets none of this.)
IMAGE_INSTALL:append:am62pxx-evm = " \
    ti-img-rogue-umlibs \
    mesa-megadriver \
    libegl libgles2 libgbm \
"

# Raw SD-card image; the workflow relabels it to <device>-slint-demo.img and zips
# it. The machine (am62pxx-evm / am62lxx-evm) provides the TI SD-card WKS
# (tiboot3/tispl/u-boot boot partition + ext4 rootfs).
IMAGE_FSTYPES = "wic"

# AM62L has no GPU. The autostarted demo picks the Skia software backend via its
# systemd unit; also default interactive/remote-viewer (slint-viewer) runs to it
# by putting it in the login environment. (systemd services don't read
# /etc/environment, hence the separate unit setting.)
set_slint_software_backend() {
    echo 'SLINT_BACKEND=linuxkms-skia-software' >> ${IMAGE_ROOTFS}${sysconfdir}/environment
}
ROOTFS_POSTPROCESS_COMMAND:append:am62lxx-evm = " set_slint_software_backend;"
