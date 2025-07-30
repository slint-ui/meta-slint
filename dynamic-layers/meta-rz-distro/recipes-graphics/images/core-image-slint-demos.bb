SUMMARY = "A very basic image with Slint demos running via KMS/DRM"

IMAGE_FEATURES += "package-management ssh-server-dropbear hwcodecs"

LICENSE = "MIT"

inherit core-image

CORE_IMAGE_BASE_INSTALL += "slint-demos liberation-fonts"

QB_MEM = "-m 512"

require include/rz-distro-common.inc
require include/rz-modules-common.inc
