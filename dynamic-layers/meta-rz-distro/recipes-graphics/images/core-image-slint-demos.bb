SUMMARY = "A very basic image with Slint demos running via KMS/DRM"

IMAGE_FEATURES += "package-management ssh-server-dropbear"

# On-target profiling and debugging: tools-debug brings gdb, gdbserver and
# strace. The profiling tools are listed instead of using tools-profile, which
# pulls in lttng-modules, LTTng's out-of-tree kernel tracer -- it doesn't build
# against every vendor kernel (2.13.12 fails on Toradex's 6.6), and lttng-tools
# would bring it back as a recommendation (still built), so leave LTTng out.
IMAGE_FEATURES += "tools-debug"
CORE_IMAGE_EXTRA_INSTALL += "perf powertop systemtap blktrace"

LICENSE = "MIT"

inherit core-image

CORE_IMAGE_BASE_INSTALL += "slint-launcher slint-viewer liberation-fonts"

QB_MEM = "-m 512"

require include/rz-distro-common.inc
require include/rz-modules-common.inc
