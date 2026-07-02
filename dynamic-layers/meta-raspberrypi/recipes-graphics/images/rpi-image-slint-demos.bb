SUMMARY = "A minimal image with the Slint demos, running on the Raspberry Pi via KMS/DRM"

LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "ssh-server-dropbear"

CORE_IMAGE_BASE_INSTALL += " \
    slint-demos \
    liberation-fonts \
"

# Emit a compressed .wic plus its block map, so the workflow can publish an
# image that is flashable directly with bmaptool. WKS_FILE is the SD-card
# layout shipped by meta-raspberrypi (FAT boot partition + ext4 rootfs).
IMAGE_FSTYPES = "wic.zst wic.bmap"
WKS_FILE = "sdimage-raspberrypi.wks"
