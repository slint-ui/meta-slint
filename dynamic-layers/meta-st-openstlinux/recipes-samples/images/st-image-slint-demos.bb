SUMMARY = "A minimal OpenSTLinux image with the Slint demos, running via KMS/DRM"
LICENSE = "GPL-3.0-only | Slint-Commercial"

include recipes-st/images/st-image.inc

inherit core-image features_check

# LinuxKMS framebuffer backend, so no compositor.
CONFLICT_DISTRO_FEATURES = "x11 wayland"

IMAGE_LINGUAS = "en-us"

IMAGE_FEATURES += "ssh-server-dropbear"

# On-target profiling and debugging: tools-debug brings gdb, gdbserver and
# strace. The profiling tools are listed instead of using tools-profile, which
# pulls in lttng-modules, LTTng's out-of-tree kernel tracer -- it doesn't build
# against every vendor kernel (2.13.12 fails on Toradex's 6.6), and lttng-tools
# would bring it back as a recommendation (still built), so leave LTTng out.
IMAGE_FEATURES += "tools-debug"
CORE_IMAGE_EXTRA_INSTALL += "perf powertop systemtap blktrace"

# Python with the full standard library, so the packages installed with uv
# (which the demo-image builds add) find the modules they expect.
CORE_IMAGE_EXTRA_INSTALL += "python3 python3-modules"

# Just the demos (+ fonts), none of the dev framework st-example-image-slint
# pulls in, to keep the image and its flashing bundle small.
# The launcher is the boot entry point (autostarts via slint-launcher.service),
# and RDEPENDS the demos + viewer it launches.
CORE_IMAGE_EXTRA_INSTALL += " \
    packagegroup-framework-sample-slint \
    slint-launcher \
"

# Mounts the bootfs, vendorfs and userfs partitions. ST's images get it from
# packagegroup-framework-core-base; without it, /vendor stays empty, and that's
# where gcnano installs its EGL, GBM and Vulkan libraries.
CORE_IMAGE_EXTRA_INSTALL += "systemd-mount-partitions"

# Vulkan on the STM32MP25: the loader. gcnano-userland already pulls in its ICD
# (libvulkan-driver-gcnano), but the loader is dlopen()ed, so nothing depends on it.
# Keyed on the vulkan DISTRO_FEATURE, which the build script keeps only for MP2.
CORE_IMAGE_EXTRA_INSTALL += "${@bb.utils.contains('DISTRO_FEATURES', 'vulkan', 'vulkan-loader', '', d)}"
