DESCRIPTION = "An image that includes Slint demos machine."

LICENSE = "MIT"

inherit core-image

CORE_IMAGE_EXTRA_INSTALL += " \
    packagegroup-fsl-tools-gpu \
    packagegroup-fsl-gstreamer1.0 \
    packagegroup-imx-tools-audio \
    slint-demos \
    liberation-fonts \
"

