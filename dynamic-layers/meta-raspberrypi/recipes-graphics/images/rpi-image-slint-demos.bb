SUMMARY = "A minimal image with the Slint demos, running on the Raspberry Pi via KMS/DRM"

LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "ssh-server-dropbear"

CORE_IMAGE_BASE_INSTALL += " \
    slint-demos \
    liberation-fonts \
"

# Networking: this image runs systemd (see INIT_MANAGER in the build script), so
# bring the network up with systemd-networkd. systemd-conf ships the default
# wired.network (DHCP on en*/eth*), and avahi provides zeroconf/mDNS so the board
# is reachable as <hostname>.local and can resolve other .local hosts.
CORE_IMAGE_BASE_INSTALL += " \
    systemd-conf \
    avahi-daemon \
    avahi-utils \
    libnss-mdns \
"

# Emit a plain, uncompressed raw disk image (.wic). The workflow relabels it to
# <device>-slint-demo.img and bundles it into <device>-slint-demo.zip;
# balenaEtcher opens the zip and flashes the single raw .img to an SD card.
# WKS_FILE is the SD-card layout shipped by meta-raspberrypi (FAT boot + ext4
# rootfs).
IMAGE_FSTYPES = "wic"
WKS_FILE = "sdimage-raspberrypi.wks"
