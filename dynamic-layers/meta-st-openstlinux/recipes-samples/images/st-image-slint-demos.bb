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
# The launcher is the boot entry point (autostarts via slint-launcher.service),
# and RDEPENDS the demos + viewer it launches.
CORE_IMAGE_EXTRA_INSTALL += " \
    packagegroup-framework-sample-slint \
    slint-launcher \
"

# Vulkan on the STM32MP25: the loader. gcnano-userland already pulls in its ICD
# (libvulkan-driver-gcnano), but the loader is dlopen()ed, so nothing depends on it.
# Keyed on the vulkan DISTRO_FEATURE, which the build script keeps only for MP2.
CORE_IMAGE_EXTRA_INSTALL += "${@bb.utils.contains('DISTRO_FEATURES', 'vulkan', 'vulkan-loader', '', d)}"
