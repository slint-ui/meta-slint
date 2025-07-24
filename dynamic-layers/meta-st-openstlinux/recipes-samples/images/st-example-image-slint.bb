SUMMARY = "ST example of image based on Slint framework."
LICENSE = "GPLv3|Slint-Commercial"

include recipes-st/images/st-image.inc

inherit core-image features_check

CONFLICT_DISTRO_FEATURES = "x11 wayland"

IMAGE_LINGUAS = "en-us"

IMAGE_FEATURES += " \
    package-management  \
    ssh-server-dropbear \
    hwcodecs            \
    tools-profile       \
    eclipse-debug       \
    "

# Define ROOTFS_MAXSIZE to 3GB
IMAGE_ROOTFS_MAXSIZE = "3145728"

# Set ST_EXAMPLE_IMAGE property to '1' to allow specific use in image creation process
ST_EXAMPLE_IMAGE = "1"

#
# INSTALL addons
#
CORE_IMAGE_EXTRA_INSTALL += " \
    resize-helper \
    \
    packagegroup-framework-core-base    \
    packagegroup-framework-tools-base   \
    \
    packagegroup-framework-core         \
    packagegroup-framework-tools       \
    \
    packagegroup-framework-core-extra   \
    \
    packagegroup-framework-sample-slint \
    "
