SUMMARY = "A minimal OpenSTLinux image with the Slint demos, running via KMS/DRM"
LICENSE = "GPL-3.0-only | Slint-Commercial"

include recipes-st/images/st-image.inc

inherit core-image features_check

# LinuxKMS framebuffer backend, so no compositor.
CONFLICT_DISTRO_FEATURES = "x11 wayland"

IMAGE_LINGUAS = "en-us"

IMAGE_FEATURES += "ssh-server-dropbear"

# Just the demos (+ fonts), none of the dev framework st-example-image-slint
# pulls in, to keep the image and its flashing bundle small.
CORE_IMAGE_EXTRA_INSTALL += " \
    packagegroup-framework-sample-slint \
"
